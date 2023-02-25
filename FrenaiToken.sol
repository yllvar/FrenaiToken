// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts 

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract FrenaiToken is ERC20, Ownable, ReentrancyGuard {
   using SafeMath for uint256;

uint8 public buyTaxRate = 5;
uint8 public sellTaxRate = 5;
uint256 private constant MAX_SCALING_FACTOR = 2e18;
uint256 private constant MIN_SCALING_FACTOR = 5e17;
uint256 private constant TOTAL_SUPPLY = 100000000e18;
uint8 public liquidityTax = 2;
uint8 public teamTax = 1;
uint8 public developmentTax = 1;
uint8 public marketingTax = 1;
AggregatorV3Interface private priceFeed;


constructor(uint256 _initialSupply, uint256 _targetPrice) ERC20("Frenai Token", "FRENAI") {
   totalSupplyLast = TOTAL_SUPPLY;
   teamWallet = msg.sender;
   developmentWallet = msg.sender;
   marketingWallet = msg.sender;
   liquidityWallet = msg.sender;
   targetPrice = _targetPrice;
   buyTaxRate = 5;
   sellTaxRate = 5;
   requiredPoolSize = 1000 ether;
   priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419); // Replace with the actual address of the price feed aggregator contract on the Ethereum mainnet
   _mint(msg.sender, _initialSupply);
}


function _applyTax(uint256 amount, uint256 taxRate) private pure returns (uint256) {
   return amount * taxRate / 100;
}

function applyTransferTaxes(uint256 amount) private {
    uint256 totalTax = _applyTax(amount, sellTaxRate + buyTaxRate);
    for (uint256 i = 0; i < 4; i++) {
        address wallet;
        uint256 taxPercent;
        if (i == 0) {
            wallet = address(this);
            taxPercent = liquidityTax;
        } else if (i == 1) {
            wallet = teamWallet;
            taxPercent = teamTax;
        } else if (i == 2) {
            wallet = developmentWallet;
            taxPercent = developmentTax;
        } else {
            wallet = marketingWallet;
            taxPercent = marketingTax;
        }
        uint256 taxAmount = _applyTax(amount, taxPercent);
        safeTransfer(wallet, taxAmount);
        emit Transfer(msg.sender, wallet, taxAmount);
        totalTax -= taxAmount;
    }
    if (totalTax > 0) {
        _burn(msg.sender, totalTax);
        emit Transfer(msg.sender, address(0), totalTax);
    }
}

function applySellTaxes(uint256 amount) private {
    uint256 taxAmount = _applyTax(amount, sellTaxRate);
    safeTransfer(address(this), taxAmount);
    emit Transfer(msg.sender, address(this), taxAmount);
    applyTransferTaxes(amount - taxAmount);
}

function applyBuyTaxes(uint256 amount) private {
    uint256 taxAmount = _applyTax(amount, buyTaxRate);
    safeTransfer(address(this), taxAmount);
    emit Transfer(msg.sender, address(this), taxAmount);
    applyTransferTaxes(amount - taxAmount);
}

function setSellTaxRate(uint8 _sellTaxRate) public {
   require(msg.sender == owner(), "Only the contract owner can call this function");
   sellTaxRate = _sellTaxRate;
}

function setBuyTaxRate(uint8 _buyTaxRate) public {
   require(msg.sender == owner(), "Only the contract owner can call this function");
   buyTaxRate = _buyTaxRate;
}


function buy() public payable {
   uint256 amountToBuy = msg.value * targetPrice / 1e18;
   uint256 amountInWei = msg.value;
   uint256 balanceBefore = balanceOf(address(this));
   applyTaxes(amountToBuy, false);
   uint256 balanceAfter = balanceOf(address(this));
   uint256 tokensBought = balanceAfter - balanceBefore;
   require(tokensBought > 0, "Insufficient liquidity");
   _mint(msg.sender, tokensBought);
   (bool success,) = address(this).call{value: amountInWei}("");
   require(success, "ETH transfer failed");
}


function sell(uint256 amount) public {
   require(amount > 0, "Amount must be greater than 0");
   uint256 balanceBefore = balanceOf(address(this));
   _transfer(msg.sender, address(this), amount);
   applyTaxes(amount, true);
   uint256 balanceAfter = balanceOf(address(this));
   uint256 ethToReturn = balanceBefore - balanceAfter;
   uint256 ethToTransfer = ethToReturn * targetPrice / 1e18;
   msg.sender.transfer(ethToTransfer);
}


function transfer(address recipient, uint256 amount) public returns (bool) {
   uint256 taxAmount = _applyTax(amount, sellTaxRate);
   uint256 totalTax = taxAmount.mul(4);
   uint256 netAmount = amount.sub(totalTax);


   uint256 liquidityShare = taxAmount.mul(2);
   uint256 teamShare = taxAmount;
   uint256 developmentShare = taxAmount;
   uint256 marketingShare = taxAmount;


   _transferFromSender(msg.sender, recipient, netAmount);
   _transferFromSender(msg.sender, liquidityWallet, liquidityShare);
   _transferFromSender(msg.sender, teamWallet, teamShare);
   _transferFromSender(msg.sender, developmentWallet, developmentShare);
   _transferFromSender(msg.sender, marketingWallet, marketingShare);


   return true;
}


function _transferFromSender(address sender, address recipient, uint256 amount) private {
   _transfer(sender, recipient, amount);
}


function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
   rebase();


   // Use SafeMath library to prevent underflows
   return super.transferFrom(sender, recipient, SafeMath.sub(amount, allowance[sender][msg.sender]));
}


// Cache frequently used values
function transfer(address recipient, uint256 amount) public returns (bool) {
   uint256 taxAmount = _applyTax(amount, SELL_TAX_RATE);
   uint256 totalTax = taxAmount.mul(4);
   uint256 netAmount = amount.sub(totalTax);


   _transfer(msg.sender, recipient, netAmount);
   _transferTo(liquidityWallet, taxAmount.mul(2));
   _transferTo(teamWallet, taxAmount);
   _transferTo(developmentWallet, taxAmount);
   _transferTo(marketingWallet, taxAmount);


   return true;
}


function rebase() external {
   uint256 currentSupply = totalSupply();
   if (currentSupply == totalSupplyLast) {
       return;
   }


   uint256 scalingFactor = targetPrice.mul(MAX_SCALING_FACTOR).div(priceFeed.latestAnswer()).div(currentSupply);
   scalingFactor = scalingFactor > MAX_SCALING_FACTOR ? MAX_SCALING_FACTOR : scalingFactor < MIN_SCALING_FACTOR ? MIN_SCALING_FACTOR : scalingFactor;


   uint256 rebasedSupply = currentSupply.mul(scalingFactor).div(1e18);
   uint256 rebasedAmount = rebasedSupply.sub(currentSupply);


   _mint(msg.sender, rebasedAmount);
   totalSupplyLast = rebasedSupply;
}


function gradualRebase() public onlyTrusted {
   uint256 totalSupplyNow = totalSupply();
   uint256 scalingFactor = 1e18;
   uint256 priceChangeFactor = getCurrentPrice().mul(1e18).div(targetPrice);


   if (priceChangeFactor != 1e18) {
       uint256 percentChange = priceChangeFactor > 1e18 ? priceChangeFactor.sub(1e18) : 1e18.sub(priceChangeFactor);
       uint256 gradualFactor = percentChange.div(30); // rebase duration is 30 days
       uint256 timeElapsed = block.timestamp - lastRebaseTimestamp;
       uint256 totalScalingFactor = timeElapsed < 7 days ? 1e18.add(gradualFactor.mul(timeElapsed).div(30 days)) : priceChangeFactor;


       totalScalingFactor = totalScalingFactor > 2e18 ? 2e18 : totalScalingFactor;
       totalScalingFactor = totalScalingFactor < 5e17 ? 5e17 : totalScalingFactor;


       scalingFactor = scalingFactor.mul(totalScalingFactor).div(1e18);
   } else {
       scalingFactor = 1e18;
   }


   _rebase(totalSupplyNow.mul(scalingFactor).div(1e18));
   lastRebaseTimestamp = block.timestamp;
}


function _updateRebase() private {
   uint256 currentPoolPrice = getPoolPrice();
   uint256 scalingFactor = calculateScalingFactor(currentPoolPrice);
   uint256 totalSupply = totalSupply();
   uint256 targetSupply = scalingFactor.mul(TOTAL_SUPPLY).div(1e18);
   uint256 delta = targetSupply > totalSupply ? targetSupply.sub(totalSupply) : totalSupply.sub(targetSupply);
   if (delta > 0) {
       uint256 rebaseAmount;
   }
}  


  function addLiquidity() public payable {
   require(msg.value > 0, "Amount must be greater than zero");
   require(balanceOf(msg.sender) > 0, "Sender must have a positive balance");


   // Calculate current price and target price
   uint256 currentPrice = currentPrice();
   uint256 targetPrice = targetPrice();


   // Calculate current pool size and required pool size
   uint256 currentPoolSize = address(this).balance;
   uint256 requiredPoolSize = totalSupply().mul(targetPrice).div(1e18);


   // Calculate the amount of tokens to mint and send to the sender
   uint256 tokensToMint = msg.value.mul(1e18).div(currentPrice);
   uint256 requiredBalance = requiredPoolSize.sub(currentPoolSize);
   if (tokensToMint.mul(targetPrice).div(1e18) > requiredBalance) {
       tokensToMint = requiredBalance.mul(1e18).div(targetPrice);
   }


   // Calculate the tax to be applied to the transaction
   uint256 tax = msg.value.mul(5).div(100);
   uint256 liquidityFee = tax.mul(2).div(5);


   // Adjust the pool size by the received amount of Ether
   uint256 newPoolSize = currentPoolSize.add(msg.value.sub(tax));
   require(newPoolSize >= requiredPoolSize, "Insufficient liquidity");


   // Mint and send the required amount of tokens to the sender
   _mint(msg.sender, tokensToMint);


   // Update the target price based on the new price
   uint256 newPrice = newPoolSize.mul(1e18).div(totalSupply());
   if (newPrice > targetPrice.mul(120).div(100)) {
       targetPrice = targetPrice.mul(110).div(100);
   } else if (newPrice < targetPrice.mul(80).div(100)) {
       targetPrice = targetPrice.mul(90).div(100);
   }
   setTargetPrice(targetPrice);


   // Transfer the received Ether to the contract and add liquidity fee to the contract's balance
   (bool success, ) = address(this).call{value: msg.value.sub(tax).sub(liquidityFee)}("");
   require(success, "Transfer failed");
}


   function removeLiquidity(uint256 amount) public {
   require(amount > 0, "Amount must be greater than zero");
   require(balanceOf(msg.sender) >= amount, "Insufficient balance");


   uint256 currentPoolSize = address(this).balance;
   uint256 currentPoolPrice = currentPoolSize.mul(1e18).div(totalSupply());


   uint256 etherAmount = amount.mul(currentPoolPrice).div(1e18);


   // Transfer Ether to the sender
   (bool success, ) = msg.sender.call{value: etherAmount}("");
   require(success, "Transfer failed");


   // Calculate required pool size and new price
   uint256 targetPoolPrice = targetPrice;
   uint256 requiredPoolSize = totalSupply().mul(targetPoolPrice).div(1e18);
   uint256 newPoolSize = currentPoolSize.sub(etherAmount);
   require(newPoolSize >= requiredPoolSize, "Insufficient liquidity");


   uint256 newPrice = newPoolSize.mul(1e18).div(totalSupply());
}


function targetPriceFeed(AggregatorV3Interface aggregator) public {
   priceFeed = aggregator;
}


function updateTargetPrice() public {
   // Get the latest price from the price feed aggregator
   uint256 newPrice = getCurrentPrice();


   // Update target price if necessary
   if (newPrice > targetPoolPrice.mul(120).div(100)) {
       targetPrice = targetPoolPrice.mul(110).div(100);
   } else if (newPrice < targetPoolPrice.mul(80).div(100)) {
       targetPrice = targetPoolPrice.mul(90).div(100);
   }


   // Transfer tokens from the sender to the contract and burn them
   _transfer(msg.sender, address(this), amount);
   _burn(address(this), amount);


   // Update the target price
   setTargetPrice(targetPrice);
}


function getCurrentPrice() public view returns (uint256) {
   return priceFeed.latestAnswer();
}


function getPoolPrice() public view returns (uint256) {
   if (_cachedPoolPrice == 0) {
       _cachedPoolPrice = address(this).balance.mul(1e18).div(totalSupply());
   }
   return _cachedPoolPrice;
}


function tradingVolume() public view returns (uint256) {
   return totalSupply().sub(balanceOf(address(this)));
}


function setTargetPrice(uint256 _targetPrice) public {
   require(msg.sender == owner(), "Caller is not the owner");
   require(_targetPrice > 0, "Price must be greater than zero");
   targetPrice = _targetPrice;
}


function decimals() public view virtual override returns (uint8) {
   return 18;
}
}