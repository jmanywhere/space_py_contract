from brownie import accounts
from scripts.deploy import deployDust
from web3 import Web3
import pytest

# Testing DustToken.sol
# FUNCTIONS CHANGED FROM PRIVATE TO PUBLIC FOR THESE TESTS
# PLEASE CHANGE THE FOLLOWING FUNCTIONS BACK
# #1 swapForEth
# #2 getPercentages
# #3 swapRewardsAndDistribute


minter = accounts[0]
user1 = accounts[1]
user2 = accounts[2]
mktWallet = accounts[3]
pair = accounts[4]
dev = accounts[5]
router = accounts[6]
dustToEth = "1"


@pytest.fixture
def token():

    return deployDust()


def test_swapForEth(token, pair, router):

    # Swapping dust to eth
    token.swapForEth(100, {"from": minter})

    # Checking wallet for eth balance
    assert Web3.eth.balanceOf(minter) == Web3.toWei(dustToEth * 100, "ether")


def test_getPercentages(token, pair, router):
    return True


def test_swapRewardsAndDistribute(token, pair, router):

    return True


def test_beforeTokenTransfer(token):

    return True


def test_afterTokenTransfer(token):
    return True


def test_transfer(token, pair, router):
    token.transfer(user1, Web3.toWei("1", "ether"), {"from": minter})
    print(f"balance of user1 {token.balanceOf(user1)}")
    assert token.balanceOf(user1) == Web3.toWei("1", "ether")


def test_AddPair(token, pair, router):
    return True


def test_buyFee(token, pair, router):
    return True


def test_sellFee(token, pair, router):
    return True


def test_taxBuy(token, pair, router):
    return True


def test_taxSell(token, pair, router):
    return True


def test_setFees(token, pair, router):
    return True


def test_setMarketingWallet(token, pair, router):
    return True
