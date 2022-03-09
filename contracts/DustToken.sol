//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IUniswapV2Router02.sol";

contract DustToken is ERC20, Ownable {
    // Fee Percentages
    uint256 public liqFeeBuy;
    uint256 public liqFeeSell;
    uint256 public bnbFee;
    uint256 public marketingFee;
    uint256 public devFee;
    uint256 public constant minSwap = 500000 ether;
    // Global amounts held
    uint256 public liqAmount;
    uint256 public marketingAmount;
    uint256 public devAmount;
    // Constants
    uint256 public constant DIVISOR = 10000;
    // Lock for swaps happening
    bool public swapping;
    address public devAddress;
    address public marketingAddress;
    // Router
    IUniswapV2Router02 public uniswapV2Router;

    mapping(address => bool) public isPair;
    mapping(address => bool) public feeExcluded;
    mapping(address => bool) public rewardExcluded;

    event LogEvent(string data);
    event AddedPair(address indexed _pair);
    event UpdatedFees(
        uint256 _bnb,
        uint256 _liqSell,
        uint256 _liqBuy,
        uint256 _marketing,
        uint256 _dev
    );
    event UpdateMarketing(address _new, address _old);

    constructor() ERC20("Spacedust Bnb", "DUST") {
        _mint(msg.sender, 100 ether);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        uint256 currentBalance = balanceOf(address(this));
        bool canSwap = currentBalance >= minSwap;
        if (!swapping && !isPair[from] && from != owner() && to != owner()) {
            swapping = true;
            swapRewardsAndDistribute(currentBalance);
            swapping = false;
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }
        uint256 liquidityFee;
        uint256 rewardFee;
        uint256 marketing;
        uint256 dev;
        if (!feeExcluded[from] && !swapping) {
            // BUY
            if (isPair[from])
                (amount, liquidityFee, rewardFee) = taxBuy(amount);
            // SELL
            if (isPair[to])
                (amount, liquidityFee, rewardFee, marketing, dev) = taxSell(
                    amount
                );
            super._transfer(
                from,
                address(this),
                liquidityFee + rewardFee + marketing + dev
            );
            liqAmount += liquidityFee;
            marketingAmount += marketing;
            devAmount += dev;
        }
        super._transfer(from, to, amount);
    }

    function addPair(address _pairAddress) external onlyOwner {
        require(!isPair[_pairAddress], "Already added");
        isPair[_pairAddress] = true;
        emit AddedPair(_pairAddress);
    }

    function buyFee() public view returns (uint256 _fee) {
        _fee = liqFeeBuy + bnbFee;
    }

    function sellFee() public view returns (uint256 _fee) {
        _fee = liqFeeSell + bnbFee + marketingFee + devFee;
    }

    function taxBuy(uint256 amount)
        private
        returns (
            uint256 _newAmount,
            uint256 _liq,
            uint256 _bnb
        )
    {
        _bnb = (bnbFee * amount) / DIVISOR;
        _liq = (liqFeeBuy * amount) / DIVISOR;
        uint256 totalFee = _bnb + _liq;
        _newAmount = amount - totalFee;
    }

    function taxSell(uint256 amount)
        private
        returns (
            uint256 _newAmount,
            uint256 _liq,
            uint256 _bnb,
            uint256 _marketing,
            uint256 _dev
        )
    {
        _bnb = (bnbFee * amount) / DIVISOR;
        _liq = (liqFeeBuy * amount) / DIVISOR;
        _dev = (devFee * amount) / DIVISOR;
        _marketing = (marketingFee * amount) / DIVISOR;
        uint256 totalFee = _bnb + _liq + _marketing + _dev;
        _newAmount = amount - totalFee;
    }

    function swapRewardsAndDistribute(uint256 currentBalance) private {
        uint256 bnb = currentBalance - liqAmount - marketingAmount - devAmount;
        uint256 half = liqAmount / 2;
        uint256 liqOtherHalf = liqAmount - half;
        swapForEth(currentBalance - liqOtherHalf);
        uint256 ethBalance = address(this).balance;
        uint256[4] memory balances = getPercentages(
            [bnb, half, marketingAmount, devAmount],
            currentBalance - liqOtherHalf,
            ethBalance
        );
        //sendToDividends( balances[0]);
        ethBalance -= balances[0];
        //makeLiquidity(balances[1]);
        ethBalance -= balances[1];
        liqAmount = 0;
        // MarketingFunds Transfer
        if (balances[2] > 0) {
            (bool success, ) = payable(marketingAddress).call{
                value: balances[2]
            }("");
            if (success) marketingAmount = 0;
            ethBalance -= balances[2];
        }
        // DevFunds Transfer
        if (balances[3] > 0) {
            (bool success, ) = payable(devAddress).call{value: ethBalance}("");
            if (success) {
                devAmount = 0;
            }
        }
    }

    function swapForEth(uint256 amount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), amount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function getPercentages(
        uint256[4] memory percentages,
        uint256 base,
        uint256 multiplier
    ) private pure returns (uint256[4] memory _finalValues) {
        for (uint8 i = 0; i < percentages.length; i++) {
            _finalValues[i] = (percentages[i] * multiplier) / base;
        }
    }

    function setFees(
        uint256 _bnb,
        uint256 _liqSell,
        uint256 _liqBuy,
        uint256 _marketing,
        uint256 _dev
    ) external onlyOwner {
        require(_bnb + _liqSell + _marketing + _dev <= 4000, "High fees");
        require(_bnb + _liqBuy <= 4000, "High fees");
        bnbFee = _bnb;
        liqFeeBuy = _liqBuy;
        liqFeeSell = _liqSell;
        marketingFee = _marketing;
        devFee = _dev;
        emit UpdatedFees(_bnb, _liqSell, _liqBuy, _marketing, _dev);
    }

    function setMarketingWallet(address payable _marketingWallet)
        external
        onlyOwner
    {
        require(_marketingWallet != address(0), "use Marketing");
        emit UpdateMarketing(_marketingWallet, marketingAddress);
        marketingAddress = _marketingWallet;
    }
}
