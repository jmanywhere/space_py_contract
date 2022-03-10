from datetime import datetime
from brownie import accounts, DustToken, Contract, interface, network
from scripts.deploy import deploy_libraries
from web3 import Web3


def deploy_token():
    deploy_libraries()
    dust = DustToken.deploy({"from": accounts[0]})
    pair = dust.mainPair()
    router = interface.IUniswapV2Router02(dust.uniswapV2Router())
    return dust, pair, router


def main():
    dust, pair, router = deploy_token()
    if network.show_active() == "development":
        # ADD LIQUIDITY
        router.addLiquidityETH(
            dust.address,
            Web3.toWei("15000000000"),
            0,
            0,
            accounts[0],
            int((datetime.now() - datetime(1970, 1, 1)).total_seconds()) + 300,
        )
        # TRANSFER BETWEEN USERS
        dust.transfer(accounts[1], Web3.toWei("750000"))
        dust.transfer(accounts[2], Web3.toWei("550000"))
        dust.transfer(accounts[3], Web3.toWei("50000"))
        # BUY
        # CHECK TAX
        # SELL
        # CHECK TAX
        # add liquidity
        # remove liquidity
