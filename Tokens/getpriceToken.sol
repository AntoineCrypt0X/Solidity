// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Uniswap.sol";

contract PriceInterface{

   IUniswapV2Pair public immutable pair_uniswap;

   constructor(address _pair_uniswap) {
      pair_uniswap=IUniswapV2Pair(_pair_uniswap);
   }

   function getTokenPrice() public view returns(uint)
   {
    (uint Res0, uint Res1,) = pair_uniswap.getReserves();
    uint res0 = Res0*(10**18);
    return((res0)/Res1); 
   }

}
