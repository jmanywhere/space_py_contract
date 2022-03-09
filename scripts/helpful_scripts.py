from brownie import network


def isDevNetwork():
    return network.show_active() == "development"
