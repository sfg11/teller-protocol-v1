// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Storage
import { DappMods } from "./DappMods.sol";
import { PausableMods } from "../contexts2/pausable/PausableMods.sol";
import { LibDapps } from "./libraries/LibDapps.sol";
import { PrizePoolInterface } from "./interfaces/PrizePoolInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PoolTogetherFacet is PausableMods, DappMods {
    using SafeERC20 for IERC20;
    /**
     * @notice This event is emitted every time Pool Together depositTo is invoked successfully.
     * @param tokenAddress address of the underlying token.
     * @param ticketAddress pool ticket token address.
     * @param amount amount of tokens deposited.
     * @param tokenBalance underlying token balance after depositing.
     * @param creditBalanceAfter pool together credit after depositing.
     */
    event PoolTogetherDeposited(
        address indexed tokenAddress,
        address indexed ticketAddress,
        uint256 amount,
        uint256 tokenBalance,
        uint256 creditBalanceAfter
    );

    /**
     * @notice This event is emitted every time Pool Together withdrawInstantlyFrom is invoked successfully.
     * @param tokenAddress address of the underlying token.
     * @param ticketAddress pool ticket token address.
     * @param amount amount of tokens to Redeem.
     * @param tokenBalance underlying token balance after Redeem.
     * @param creditBalanceAfter pool together credit after depositing.
     */
    event PoolTogetherWithdrawal(
        address indexed tokenAddress,
        address indexed ticketAddress,
        uint256 amount,
        uint256 tokenBalance,
        uint256 creditBalanceAfter
    );

    /**
     * @notice This function deposits the users funds into a Pool Together Prize Pool for a ticket.
     * @param loanID id of the loan being used in the dapp
     * @param tokenAddress address of the token.
     * @param amount of tokens to deposit.
     */
    function poolTogetherDepositTicket(
        uint256 loanID,
        address tokenAddress,
        uint256 amount
    ) public paused("", false) onlyBorrower(loanID) {
        require(
            LibDapps.balanceOf(loanID, tokenAddress) >= amount,
            "POOL_INSUFFICIENT_UNDERLYING"
        );

        PrizePoolInterface prizePool = LibDapps.getPrizePool(tokenAddress);

        address ticketAddress = LibDapps.getTicketAddress(tokenAddress);
        uint256 balanceBefore = LibDapps.balanceOf(loanID, ticketAddress);
        IERC20(tokenAddress).safeApprove(address(prizePool), amount);

        prizePool.depositTo(
            address(this),
            amount,
            ticketAddress,
            address(this)
        );

        uint256 balanceAfter = LibDapps.balanceOf(loanID, ticketAddress);
        require(balanceAfter > balanceBefore, "DEPOSIT_ERROR");

        LibDapps.tokenUpdated(loanID, address(ticketAddress));
        LibDapps.tokenUpdated(loanID, tokenAddress);

        emit PoolTogetherDeposited(
            tokenAddress,
            ticketAddress,
            amount,
            balanceBefore,
            balanceAfter
        );
    }

    /**
     * @notice This function withdraws the users funds from a Pool Together Prize Pool.
     * @param loanID id of the loan being used in the dapp
     * @param tokenAddress address of the token.
     * @param amount The amount of tokens to withdraw.
     */
    function poolTogetherWithdraw(
        uint256 loanID,
        address tokenAddress,
        uint256 amount
    ) public paused("", false) onlyBorrower(loanID) {
        PrizePoolInterface prizePool = LibDapps.getPrizePool(tokenAddress);

        address ticketAddress = LibDapps.getTicketAddress(tokenAddress);
        uint256 balanceBefore = LibDapps.balanceOf(loanID, ticketAddress);

        (
            uint256 maxExitFee, /* uint256 burnedCredit */

        ) =
            prizePool.calculateEarlyExitFee(
                address(this),
                ticketAddress,
                amount
            );
        prizePool.withdrawInstantlyFrom(
            address(this),
            amount,
            ticketAddress,
            maxExitFee
        );

        uint256 balanceAfter = LibDapps.balanceOf(loanID, ticketAddress);
        require(balanceAfter < balanceBefore, "WITHDRAW_ERROR");

        LibDapps.tokenUpdated(loanID, address(ticketAddress));
        LibDapps.tokenUpdated(loanID, tokenAddress);

        emit PoolTogetherWithdrawal(
            tokenAddress,
            ticketAddress,
            amount,
            balanceBefore,
            balanceAfter
        );
    }

    /**
     * @notice This function withdraws the users funds from a Pool Together Prize Pool.
     * @param loanID id of the loan being used in the dapp
     * @param tokenAddress address of the token.
     */
    function poolTogetherWithdrawAll(uint256 loanID, address tokenAddress)
        public
        paused("", false)
        onlyBorrower(loanID)
    {
        PrizePoolInterface prizePool = LibDapps.getPrizePool(tokenAddress);

        address ticketAddress = LibDapps.getTicketAddress(tokenAddress);

        uint256 balanceBefore = LibDapps.balanceOf(loanID, ticketAddress);

        (uint256 maxExitFee, ) =
            prizePool.calculateEarlyExitFee(
                address(this),
                ticketAddress,
                balanceBefore
            );
        prizePool.withdrawInstantlyFrom(
            address(this),
            balanceBefore,
            ticketAddress,
            maxExitFee
        );

        uint256 balanceAfter = LibDapps.balanceOf(loanID, ticketAddress);
        require(balanceAfter < balanceBefore, "WITHDRAW_ERROR");

        LibDapps.tokenUpdated(loanID, address(ticketAddress));
        LibDapps.tokenUpdated(loanID, tokenAddress);

        emit PoolTogetherWithdrawal(
            tokenAddress,
            ticketAddress,
            balanceBefore,
            LibDapps.balanceOf(loanID, tokenAddress),
            balanceAfter
        );
    }
}
