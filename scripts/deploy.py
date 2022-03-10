from brownie import DustToken, IterableMapping, accounts
from scripts.helpful_scripts import isDevNetwork
from web3 import Web3


def deploy_libraries():
    IterableMapping.deploy({"from": accounts[0]})


def deployDust():
    token = DustToken.deploy({"from": accounts[0]})
    return token


def main():
    if isDevNetwork():
        deploy_libraries()
    token = deployDust()
    if isDevNetwork():
        tx = token.transfer(
            accounts[1], Web3.toWei("1", "ether"), {"from": accounts[0]}
        )
        tx.wait(1)
        balance = token.balanceOf(accounts[0])
        print(f"Minter Balance {balance}")
    else:
        account = accounts.load("deployment_acc")
        print(account)
