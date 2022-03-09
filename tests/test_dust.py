from brownie import accounts
from scripts.deploy import deployDust
from web3 import Web3
import pytest


@pytest.fixture
def token():
    return deployDust()


def test_transfer(token):
    user1 = accounts[1]
    token.transfer(user1, Web3.toWei("1", "ether"), {"from": accounts[0]})
    print(f"balance of user1 {token.balanceOf(user1)}")
    assert token.balanceOf(user1) == Web3.toWei("1", "ether")


1
