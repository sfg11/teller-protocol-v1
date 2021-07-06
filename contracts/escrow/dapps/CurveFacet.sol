// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Storage
import { DappMods } from "./DappMods.sol";
import { PausableMods } from "../../settings/pausable/PausableMods.sol";

import { LibDapps } from "./libraries/LibDapps.sol";
import { LibEscrow } from "../libraries/LibEscrow.sol";

import { ICrvZap } from "./interfaces/ICrvZap.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CurveFacet is PausableMods, DappMods {
    using SafeERC20 for IERC20; // tells compiler to work with IERC20

    enum AmountType { None, Relative, Absolute }
    struct TokenAmount {
        address token;
        uint256 amount;
        AmountType amountType;
    }
    /**
        @notice This event is emitted every time the curve deposit func is invoked successfully
        @param underlyingTokenAddress address of the underlying token
        @param cvTokenAddress curve token address
        @param amountToDeposit amount of tokens to deposit
     */
    event CurveDeposited(
        address indexed underlyingTokenAddress,
        address indexed cvTokenAddress,
        uint256 amountToDeposit
    );

    // call zap add_liquidity(pool address, deposit_amount,
    // find what index maps to dai and thats the balance im going to set as the amount to deposit;
    //reciever === escrow contract)
    // get pool address(aka contract where the funds are); zap address; amt

    /**
        @notice Deposits the specified amount into curve lending pool 
        @param loanID The id of the loan being used in the dapp
        @param tokenAddress The address of the token being deposited
        @param amount The amount of tokens to be deposited into curve lending pool 
     */
    function curveDeposit(
        uint256 loanID,
        address tokenAddress,
        uint256 amount
    ) public paused("", false) onlyBorrower(loanID) {
        TokenAmount[] calldata tokenAmounts;

        ICrvZap zap = ICrvZap(0x7AbDBAf29929e7F8621B757D2a7c04d78d633834);

        address pool = 0xFD9f9784ac00432794c8D370d4910D2a3782324C;

        uint256[] memory depositAmounts = new uint256[](4);
        // require amount to be at index 1
        depositAmounts[1] = amount;

        // Encode data for LoansEscrow to call
        bytes memory callData =
            abi.encode(
                ICrvZap.add_liquidity.selector,
                pool,
                depositAmounts,
                0 // min mint amount
            );

        LibEscrow.e(loanID).setTokenAllowance(tokenAddress, address(pool));

        /**
        // if allowance < amount 
        //   if allowance > 0 
        //      ERC20(token).safeApprove....
         */

        LibEscrow.e(loanID).callDapp(pool, callData);

        /** PoolInfo poolInfo = CurvePoolInfo .. getPoolInfo(crvToken)
            totalCoins = poolInfo.totalCoings; 
            if totalCoins == 2
                try add_liquidity(depositAmounts[0], depositAmounts[1], 0) {catch {revert("deposit failed")}}
            if totalCoins == 3
                ...

         */

        // update token balance
        LibEscrow.tokenUpdated(loanID, pool);
        LibEscrow.tokenUpdated(loanID, tokenAddress);

        emit CurveDeposited(tokenAddress, pool, amount);
    }

    /**
        @notice withdraws users cTokens from previous deposit into curve pool 
        @param loanID the id of the loan being used
        @param tokenAddress The address of the token being deposited
        @param amount amount of the underlying tokens to withdraw
     */

    // function curveWithdraw(
    //     uint256 loanID,
    //     address tokenAddress,
    //     uint256 amount,
    //     bytes memory bridgeData
    // )
    //     internal
    //     returns (uint256 boughtAmount)
    // {
    //     // Decode the bridge data to get the Curve metadata.
    //     CurveBridgeDataV2 memory data = abi.decode(bridgeData, (CurveBridgeDataV2));
    //     sellToken.approveIfBelow(data.curveAddress, sellAmount);

    //     uint256 beforeBalance = buyToken.balanceOf(address(this));
    //     (bool success, bytes memory resultData) =
    //         data.curveAddress.call(abi.encodeWithSelector(
    //             data.exchangeFunctionSelector,
    //             data.fromCoinIdx,
    //             data.toCoinIdx,
    //             // dx
    //             sellAmount,
    //             // min dy
    //             1
    //         ));
    //     if (!success) {
    //         resultData.rrevert();
    //     }

    //     return buyToken.balanceOf(address(this)).safeSub(beforeBalance);
    // }
}
