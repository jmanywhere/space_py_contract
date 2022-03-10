from brownie import accounts
from scripts.deploy import deployDust
from web3 import Web3
import pytest


@pytest.fixture
def token():
    return deployDust()


def test_beforeTokenTransfer():
    return True


def test_transfer(token):
    user1 = accounts[1]
    token.transfer(user1, Web3.toWei("1", "ether"), {"from": accounts[0]})
    print(f"balance of user1 {token.balanceOf(user1)}")
    assert token.balanceOf(user1) == Web3.toWei("1", "ether")


def test_AddPair(token):
    return True


def test_buyFee(token):
    return True


def test_sellFee(token):
    return True


def test_taxBuy(token):
    return True


def test_taxSell(token):
    return True


def test_swapRewardsAndDistribute(token):
    return True


def test_swapForEth(token):
    return True


def test_getPercentages(token):
    return True


def test_setFees(token):
    return True


def test_setMarketingWallet(token):
    return True
