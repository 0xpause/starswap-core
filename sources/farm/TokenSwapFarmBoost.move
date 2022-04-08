// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0


address SwapAdmin {

module TokenSwapFarmBoost {

    use SwapAdmin::TokenSwapVestarMinter;

    struct MinterTreasuryCapabilityWrapper has key, store {
        cap: TokenSwapVestarMinter::TreasuryCapability
    }

    public fun set_treasury_cap(signer: &signer, issuer_treasury_cap: TokenSwapVestarMinter::TreasuryCapability) {
        move_to(signer, MinterTreasuryCapabilityWrapper{
            cap: issuer_treasury_cap
        });
    }

    /// Boost to farm pool
    // TODO(ElementX):
    public fun boost_to_farm_pool<X: store, Y: store>(_signer: &signer, _amount: u128) {
        // let vtoken = TokenSwapSyrupBoost::withdraw(signer, amount);
        // Stake to current contract
        // ...
    }

    /// Boost to farm pool
    // TODO(ElementX):
    public fun unboost_from_farm_pool<X: store, Y: store>(_signer: &signer) {
        // 1. Release from Boost token vestar treasury

        // 2. Deposit to TokenSwapSyrupBoost
    }
}
}