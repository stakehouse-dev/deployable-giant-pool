# Self Deployable Giant Pool

## This is a template example contract you can use however you want. However, it does not come with any warranties of any kind. Deploy at your own risk. Feel free to deploy this to Goerli network.

### Stakehouse protocol deployment information: https://github.com/stakehouse-dev/contract-deployments

# Summary

If you want to accept ETH deposits from your own giant pool whilst controlling within which LSD network it can be deposited, then this contract can offer that functionality.

Instead of allowing any LSD network to request ETH from the common giant pool deployed by Blockswap Network, this allows only the owner to decide within which LSD network to deploy capital.

It comes with its own risks - the owner (which could be any ETH address set on deployment) must take care when supplying the parameters to the `batchDepositETHForStaking`. All responsibility is on the owner to use the correct parameters.

## Two strategies

There are 2 giant pools:
- GiantSavETHVaultPool (Protected Staking)
- GiantMevAndFeesPool (Mev Staking)

### GiantSavETHVaultPool

If you want LPs to put ETH for protected staking (savETH pool requires 24 ETH per validator), use this giant pool.

The owner of the contract can decide which LSD network will receive the ETH. Owner must take care with params.

### GiantMevAndFeesPool

If you want LPs to put ETH for fees and mev staking (staking funds vault pool requires 4 ETH per validator), use this giant pool.

The owner of the contract can decide which LSD network will receive the ETH. Owner must take care with params.