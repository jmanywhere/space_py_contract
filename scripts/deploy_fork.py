from brownie import accounts, DustToken
from scripts.deploy import deploy_libraries


def deploy_token():
    deploy_libraries()
    dust = DustToken.deploy({"from": accounts[0]})
    pair = dust.mainPair()
    print(f"{pair}")


def main():
    deploy_token()
