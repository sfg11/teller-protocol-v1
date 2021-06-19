// funcs to deposit and remove liquidity  on curve

pragma solidity ^0.8.0;

interface ICrvZap {
    function add_liquidity(
        address pool,
        uint256[4] depositAmounts,
        uint256 minMintAmount
    ) external returns (uint256);

    function remove_liquidity(
        address pool,
        uint256 burnAmounts,
        uint256[4] minAmounts,
        address receiver
    ) external returns (uint256[4]);
}
