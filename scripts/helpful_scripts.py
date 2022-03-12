from brownie import network


def isDevNetwork():
    return network.show_active() in ["development", "bsc-main-fork"]
