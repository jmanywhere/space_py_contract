from datetime import datetime
from brownie import accounts, DustToken, Contract, interface, network
from scripts.deploy import deploy_libraries
from web3 import Web3

TEST_ENV = ["development", "bsc-main-fork"]


def deploy_token():
    deploy_libraries()
    dust = DustToken.deploy({"from": accounts[0]})
    pair = dust.mainPair()
    router = interface.IUniswapV2Router02(dust.uniswapV2Router())
    return dust, pair, router


def main():
    dust, pair, router = deploy_token()
    bnb_eth = router.WETH()
    if network.show_active() in TEST_ENV:
        # need 220BNB to simulate same values
        accounts[5].transfer(accounts[0].address, Web3.toWei("90", "ether"))
        accounts[6].transfer(accounts[0].address, Web3.toWei("50", "ether"))
        # ADD LIQUIDITY
        dust.approve(
            dust.uniswapV2Router(),
            Web3.toWei("100000000000", "ether"),
            {"from": accounts[0]},
        )
        router.addLiquidityETH(
            dust.address,
            Web3.toWei("15000000000", "ether"),
            0,
            0,
            accounts[0],
            int((datetime.now() - datetime(1970, 1, 1)).total_seconds()) + 30000000,
            {"from": accounts[0], "value": Web3.toWei("220", "ether")},
        )
        dust.addPair(dust.mainPair(), {"from": accounts[0]})
        # TRANSFER BETWEEN USERS
        dust.transfer(accounts[1], Web3.toWei("750000", "ether"), {"from": accounts[0]})
        dust.transfer(accounts[2], Web3.toWei("550000", "ether"), {"from": accounts[0]})
        dust.transfer(
            accounts[3], Web3.toWei("50000", "ether"), {"from": accounts[0]}
        )  # user[3] not enough tokens
        dust.transfer(
            accounts[4], Web3.toWei("5500000", "ether"), {"from": accounts[0]}
        )  # 5 million

        initDustAc2 = dust.balanceOf(accounts[2].address)
        # senders balance
        initBal = accounts[0].balance()
        # BUY
        amounts = router.swapExactETHForTokens(
            0,
            [bnb_eth, dust.address],
            accounts[2],
            int((datetime.now() - datetime(1970, 1, 1)).total_seconds()) + 6000000000,
            {"from": accounts[2], "value": Web3.toWei("0.1", "ether")},
        )
        # CHECK TAX
        ac1_balance = dust.balanceOf(accounts[2].address)
        print(f"Account1 Balance: {ac1_balance}")
        print(f"Diff {ac1_balance - initDustAc2}")

        ##Transfer shouldn't incur taxes
        dust.transfer(accounts[6], Web3.toWei("100", "ether"), {"from": accounts[3]})
        print(f"Expected: {dust.balanceOf(accounts[6])} == 100000000000000000000")
        # SELL
        # CHECK TAX
        # add liquidity
        # remove liquidity
