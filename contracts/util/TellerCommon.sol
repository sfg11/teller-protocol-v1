pragma solidity 0.5.17;

import "./NumbersList.sol";

/**
 * @dev Library of structs common across the Teller protocol
 *
 * @author develop@teller.finance
 */
library TellerCommon {
    enum LoanStatus { NonExistent, TermsSet, Active, Closed }

    /**
        @notice Represents a user signature
        @param v The recovery identifier represented by the last byte of a ECDSA signature as an int
        @param r The random point x-coordinate of the signature respresented by the first 32 bytes of the generated ECDSA signature
        @param s The signature proof represented by the second 32 bytes of the generated ECDSA signature
     */
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
        @notice Borrower request object to take out a loan
        @param borrower The wallet address of the borrower 
        @param recipient The address where funds will be sent, only applicable in over collateralized loans
        @param consensusAddress The address of the Teller loan consensus contract to which the request should be sent
        @param requestNonce The nonce of the borrower wallet address required for authentication
        @param amount The amount of tokens requested by the borrower for the loan
        @param duration The length of time in seconds that the loan has been requested for
        @param requestTime The timestamp at which the loan was requested
     */
    struct LoanRequest {
        address payable borrower;
        address recipient;
        address consensusAddress;
        uint256 requestNonce;
        uint256 amount;
        uint256 duration;
        uint256 requestTime;
        bytes32 minaProofIdHash;
    }

    /**
        @notice Borrower response object to take out a loan
        @param signer The wallet address of the signer validating the interest request of the lender
        @param consensusAddress The address of the Teller loan consensus contract to which the request should be sent
        @param responseTime The timestamp at which the response was sent
        @param interestRate The signed interest rate generated by the signer's Credit Risk Algorithm (CRA)
        @param collateralRatio The ratio of collateral to loan amount that is generated by the signer's Credit Risk Algorithm (CRA)
        @param maxLoanAmount The largest amount of tokens that can be taken out in the loan by the borrower 
        @param signature The signature generated by the signer in the format of the above Signature struct 
     */
    struct LoanResponse {
        address signer;
        address consensusAddress;
        uint256 responseTime;
        uint256 interestRate;
        uint256 collateralRatio;
        uint256 maxLoanAmount;
        Signature signature;
    }

    /**
        @notice Represents loan terms based on consensus values
        @param interestRate The consensus value for the interest rate based on all the loan responses from the signers
        @param collateralRatio The consensus value for the ratio of collateral to loan amount required for the loan, based on all the loan responses from the signers
        @param maxLoanAmount The consensus value for the largest amount of tokens that can be taken out in the loan, based on all the loan responses from the signers 
     */
    struct AccruedLoanTerms {
        NumbersList.Values interestRate;
        NumbersList.Values collateralRatio;
        NumbersList.Values maxLoanAmount;
    }

    /**
        @notice Represents the terms of a loan based on the consensus of a LoanRequest
        @param borrower The wallet address of the borrower 
        @param recipient The address where funds will be sent, only applicable in over collateralized loans
        @param interestRate The consensus interest rate calculated based on all signer loan responses
        @param collateralRatio The consensus ratio of collateral to loan amount calculated based on all signer loan responses
        @param maxLoanAmount The consensus largest amount of tokens that can be taken out in the loan by the borrower, calculated based on all signer loan responses
        @param duration The consensus length of loan time, calculated based on all signer loan responses
     */
    struct LoanTerms {
        address payable borrower;
        address recipient;
        uint256 interestRate;
        uint256 collateralRatio;
        uint256 maxLoanAmount;
        uint256 duration;
    }

    /**
        @notice Data per borrow as struct
        @param id The id of the loan for internal tracking
        @param loanTerms The loan terms returned by the signers
        @param termsExpiry The timestamp at which the loan terms expire, after which if the loan is not yet active, cannot be taken out
        @param loanStartTime The timestamp at which the loan became active
        @param collateral The total amount of collateral deposited by the borrower to secure the loan
        @param lastCollateralIn The amount of collateral that was last deposited by the borrower to keep the loan active
        @param principalOwed The total amount of the loan taken out by the borrower, reduces on loan repayments
        @param interestOwed The total interest owed by the borrower for the loan, reduces on loan repayments
        @param borrowedAmount The total amount of the loan size taken out
        @param escrow The address of the escrow contract that holds the funds taken out in the loan on behalf of the borrower
        @param status The status of the loan currently based on the LoanStatus enum - NonExistent, TermsSet, Active, Closed
        @param liquidated Flag marking if the loan has been liquidated or not 
     */
    struct Loan {
        uint256 id;
        LoanTerms loanTerms;
        uint256 termsExpiry;
        uint256 loanStartTime;
        uint256 collateral;
        uint256 lastCollateralIn;
        uint256 principalOwed;
        uint256 interestOwed;
        uint256 borrowedAmount;
        address escrow;
        LoanStatus status;
        bool liquidated;
    }

    /**
        @notice This struct represents the collateral information for a given loan.
        @param collateral the current collateral amount.
        @param valueInLendingTokens the current collateral value expressed in lending tokens.
        @param neededInLendingTokens the collateral needed expressed in lending tokens.
        @param neededInCollateralTokens the collateral needed expressed in collateral tokens.
        @param moreCollateralRequired true if the given loan requires more collateral. Otherwise it is false.
     */
    struct LoanCollateralInfo {
        uint256 collateral;
        uint256 valueInLendingTokens;
        uint256 escrowLoanValue;
        int256 neededInLendingTokens;
        int256 neededInCollateralTokens;
        bool moreCollateralRequired;
    }

    /**
        @notice This struct is used to get the current liquidation info for a given loan id.
        @param collateralInfo information for the the given loan.
        @param amountToLiquidate the needed amount to liquidate the loan (if the liquidable parameter is true).
        @param rewardInCollateral the value the liquidator will receive denoted in collateral tokens.
        @param liquidable true if the loan is liquidable. Otherwise it is false.
        @dev If the loan does not need to be liquidated, amountToLiquidate is the maximum payment amount of lending tokens that will be required to liquidate the loan.
        @dev If the loan can be liquidated, amountToLiquidate is the current payment amount of lending tokens that is needed to liquidate the loan.
        @dev Liquidation reward is the value the liquidator will receive denoted in the collateral token. It will be, at maximum, the amount of collateral required. For under collateralized loans, the remaining value will be collected from tokens held by the loan's Escrow contract.
     */
    struct LoanLiquidationInfo {
        LoanCollateralInfo collateralInfo;
        uint256 amountToLiquidate;
        int256 rewardInCollateral;
        bool liquidable;
    }

    /**
        @notice This struct defines the dapp address and data to execute in the callDapp function.
        @dev It is executed using a delegatecall in the Escrow contract.
        @param exists Flag marking whether the dapp is a Teller registered address
        @param unsecured Flag marking if the loan allowed to be used in the dapp is a secured, or unsecured loan
     */
    struct Dapp {
        bool exists;
        bool unsecured;
    }

    /**
        @notice This struct defines the dapp address and data to execute in the callDapp function.
        @dev It is executed using a delegatecall in the Escrow contract.
        @param location The proxy contract address for the dapp that will be used by the Escrow contract delegatecall
        @param data The encoded function signature with parameters for the dapp method in bytes that will be sent in the Escrow delegatecall
     */
    struct DappData {
        address location;
        bytes data;
    }

    /**
        @notice This struct defines a market in the platform.
        @dev It is used by the MarketFactory contract.
        @param loans The address for the Teller Loans contract that is being used for a market
        @param lendingPool The address for the Teller Lending Pool contract that is being used for a market
        @param loanTermsConsensus The address for the Teller Loan Terms Consensus contract that is being used for a market
        @param exists Flag marking if the market is defined on the platform or not
     */
    struct Market {
        address loans;
        address lendingPool;
        address loanTermsConsensus;
        bool exists;
    }

    /**
        @notice This struct is used to register multiple logic versions in LogicVersionsRegistry contract.
        @param logic The address for the new contract holding the logic
        @param logicName The internal name for the logic contract represented in bytes32
     */
    struct LogicVersionRequest {
        address logic;
        bytes32 logicName;
    }
}
