from brownie import DustToken, IterableMapping, accounts
from scripts.helpful_scripts import isDevNetwork
from web3 import Web3


def deploy_libraries(account, publish):
    IterableMapping.deploy({"from": account}, publish_source=publish)


def deployDust(account, publish):
    token = DustToken.deploy({"from": account}, publish_source=publish)
    return token


def main():
    if isDevNetwork():
        deploy_libraries(accounts[0], False)
        token = deployDust(accounts[0], False)
        tx = token.transfer(
            accounts[1], Web3.toWei("1", "ether"), {"from": accounts[0]}
        )
        tx.wait(1)
        balance = token.balanceOf(accounts[0])
        print(f"Minter Balance {balance}")
    else:
        account = accounts.load("deployment_acc")
        # deploy_libraries(account, True
        token = deployDust(account, True)

        print(account)
