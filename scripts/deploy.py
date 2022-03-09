from brownie import DustToken, accounts
from scripts.helpful_scripts import isDevNetwork
from web3 import Web3


def deployDust():
    token = DustToken.deploy({"from": accounts[0]})
    return token


def main():
    token = deployDust()
    if isDevNetwork():
        tx = token.transfer(
            accounts[1], Web3.toWei("1", "ether"), {"from": accounts[0]}
        )
        print(f"{tx.events}")
    else:
        print("Execute that")
