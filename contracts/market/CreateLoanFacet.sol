// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import { PausableMods } from "../settings/pausable/PausableMods.sol";
import {
    ReentryMods
} from "../contexts2/access-control/reentry/ReentryMods.sol";
import { RolesMods } from "../contexts2/access-control/roles/RolesMods.sol";
import { AUTHORIZED } from "../shared/roles.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Libraries
import { LibLoans } from "./libraries/LibLoans.sol";
import { LibEscrow } from "../escrow/libraries/LibEscrow.sol";
import { LibCollateral } from "./libraries/LibCollateral.sol";
import { LibConsensus } from "./libraries/LibConsensus.sol";
import { LendingLib } from "../lending/libraries/LendingLib.sol";
import {
    PlatformSettingsLib
} from "../settings/platform/libraries/PlatformSettingsLib.sol";
import {
    MaxDebtRatioLib
} from "../settings/asset/libraries/MaxDebtRatioLib.sol";
import {
    MaxLoanAmountLib
} from "../settings/asset/libraries/MaxLoanAmountLib.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { NumbersLib } from "../shared/libraries/NumbersLib.sol";
import { NFTLib, NftLoanSizeProof } from "../nft/libraries/NFTLib.sol";

// Interfaces
import { ILoansEscrow } from "../escrow/escrow/ILoansEscrow.sol";

// Proxy
import {
    BeaconProxy
} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

// Storage
import {
    LoanRequest,
    LoanStatus,
    LoanTerms,
    Loan,
    MarketStorageLib
} from "../storage/market.sol";
import { AppStorageLib } from "../storage/app.sol";

contract CreateLoanFacet is RolesMods, ReentryMods, PausableMods {
    /**
     * @notice This event is emitted when a loan has been successfully taken out
     * @param loanID ID of loan from which collateral was withdrawn
     * @param borrower Account address of the borrower
     * @param amountBorrowed Total amount taken out in the loan
     * @param withNFT Boolean indicating if the loan was taken out using NFTs
     */
    event LoanTakenOut(
        uint256 indexed loanID,
        address indexed borrower,
        uint256 amountBorrowed,
        bool withNFT
    );

    /**
     * @notice Creates the loan from requests and validator responses then calling the main function.
     * @param request Struct of the protocol loan request
     */
    modifier __createLoan(LoanRequest calldata request) {
        Loan storage loan = CreateLoanLib.createLoan(request);

        _;

        loan.status = LoanStatus.Active;
        loan.loanStartTime = uint32(block.timestamp);
        loan.duration = request.request.duration;
    }

    /**
     * @notice Creates a loan with the loan request and NFTs without any collateral
     * @param request Struct of the protocol loan request
     * @param proofs Merkle proofs for validating NFT base loan size
     */
    function takeOutLoanWithNFTs(
        LoanRequest calldata request,
        NftLoanSizeProof[] calldata proofs
    ) external paused(LibLoans.ID, false) __createLoan(request) {
        // Get the ID of the newly created loan
        uint256 loanID = CreateLoanLib.currentID();
        uint256 amount = LibLoans.loan(loanID).borrowedAmount;

        // Set the collateral ratio to 0 as linked NFTs are used as the collateral
        LibLoans.loan(loanID).collateralRatio = 0;

        uint256 allowedLoanSize;
        for (uint256 i; i < proofs.length; i++) {
            NFTLib.applyToLoan(loanID, proofs[i]);

            allowedLoanSize += proofs[i].baseLoanSize;
            if (allowedLoanSize >= amount) {
                break;
            }
        }
        require(
            amount <= allowedLoanSize,
            "Teller: insufficient NFT loan size"
        );

        // Pull funds from Teller Token LP and transfer to the new loan escrow
        LendingLib.tToken(LibLoans.loan(loanID).lendingToken).fundLoan(
            CreateLoanLib.createEscrow(loanID),
            amount
        );

        emit LoanTakenOut(
            loanID,
            msg.sender,
            LibLoans.loan(loanID).borrowedAmount,
            true
        );
    }

    /**
     * @notice Take out a loan
     *
     * @dev collateral ratio is a percentage of the loan amount that's required in collateral
     * @dev the percentage will be *(10**2). I.e. collateralRatio of 5244 means 52.44% collateral
     * @dev is required in the loan. Interest rate is also a percentage with 2 decimal points.
     *
     * @param request Struct of the protocol loan request
     * @param collateralToken Token address to use as collateral for the new loan
     * @param collateralAmount Amount of collateral required for the loan
     */
    function takeOutLoan(
        LoanRequest calldata request,
        address collateralToken,
        uint256 collateralAmount
    )
        external
        payable
        paused(LibLoans.ID, false)
        nonReentry("")
        authorized(AUTHORIZED, msg.sender)
        __createLoan(request)
    {
        // Verify collateral token is acceptable
        require(
            EnumerableSet.contains(
                MarketStorageLib.store().collateralTokens[
                    request.request.assetAddress
                ],
                collateralToken
            ),
            "Teller: collateral token not allowed"
        );

        // Get the ID of the newly created loan
        Loan storage loan = LibLoans.loan(CreateLoanLib.currentID());
        // Save collateral token to loan
        loan.collateralToken = collateralToken;

        // Pay in collateral
        if (collateralAmount > 0) {
            LibCollateral.deposit(loan.id, collateralAmount);
        }

        // Check that enough collateral has been provided for this loan
        require(
            LibLoans.getCollateralNeeded(loan.id) <=
                LibCollateral.e(loan.id).loanSupply(loan.id),
            "Teller: more collateral required"
        );

        // Pull funds from Teller token LP and and transfer to the recipient
        LendingLib.tToken(loan.lendingToken).fundLoan(
            LibLoans.canGoToEOAWithCollateralRatio(loan.collateralRatio)
                ? loan.borrower
                : CreateLoanLib.createEscrow(loan.id),
            loan.borrowedAmount
        );

        emit LoanTakenOut(loan.id, msg.sender, loan.borrowedAmount, false);
    }
}

library CreateLoanLib {
    function createLoan(LoanRequest calldata request)
        internal
        returns (Loan storage loan)
    {
        // Perform loan request checks
        require(
            msg.sender == request.request.borrower,
            "Teller: not loan requester"
        );
        require(
            PlatformSettingsLib.getMaximumLoanDurationValue() >=
                request.request.duration,
            "Teller: max loan duration exceeded"
        );

        // Get consensus values from request
        (uint16 interestRate, uint16 collateralRatio, uint256 maxLoanAmount) =
            LibConsensus.processLoanTerms(request);

        // Perform loan value checks
        require(
            MaxLoanAmountLib.get(request.request.assetAddress) > maxLoanAmount,
            "Teller: asset max loan amount exceeded"
        );
        require(
            LendingLib.tToken(request.request.assetAddress).debtRatioFor(
                maxLoanAmount
            ) <= MaxDebtRatioLib.get(request.request.assetAddress),
            "Teller: max supply-to-debt ratio exceeded"
        );

        // Get and increment new loan ID
        uint256 loanID = CreateLoanLib.newID();
        // Set loan data based on terms
        loan = LibLoans.loan(loanID);
        loan.id = uint128(loanID);
        loan.status = LoanStatus.TermsSet;
        loan.lendingToken = request.request.assetAddress;
        loan.borrower = request.request.borrower;
        loan.borrowedAmount = maxLoanAmount;
        loan.interestRate = interestRate;
        loan.collateralRatio = collateralRatio;
        // Set loan debt
        LibLoans.debt(loanID).principalOwed = maxLoanAmount;
        LibLoans.debt(loanID).interestOwed = LibLoans.getInterestOwedFor(
            uint256(loanID),
            maxLoanAmount
        );

        // Add loanID to borrower list
        MarketStorageLib.store().borrowerLoans[loan.borrower].push(
            uint128(loanID)
        );
    }

    function newID() internal returns (uint256 id_) {
        Counters.Counter storage counter =
            MarketStorageLib.store().loanIDCounter;
        id_ = Counters.current(counter);
        Counters.increment(counter);
    }

    function currentID() internal returns (uint256 id_) {
        Counters.Counter storage counter =
            MarketStorageLib.store().loanIDCounter;
        id_ = Counters.current(counter);
    }

    function createEscrow(uint256 loanID) internal returns (address escrow_) {
        // Create escrow
        escrow_ = AppStorageLib.store().loansEscrowBeacon.cloneProxy("");
        ILoansEscrow(escrow_).init();
        // Save escrow address for loan
        MarketStorageLib.store().loanEscrows[loanID] = ILoansEscrow(escrow_);
    }
}
