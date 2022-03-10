from brownie import accounts, DustToken
from scripts.deploy import deploy_libraries
from web3 import Web3


def deploy_token():
    deploy_libraries()
    dust = DustToken.deploy({"from": accounts[0]})
    pair = dust.mainPair()
    router = dust.uniswapV2Router()
    print(f"{pair}, {router}")
    print(f"{Web3.fromWei(accounts[0].balance(),'ether')}")


def main():
    deploy_token()
