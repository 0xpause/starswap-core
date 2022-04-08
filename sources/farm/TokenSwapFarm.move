// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {
module TokenSwapFarm {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Event;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Vector;

    use SwapAdmin::YieldFarmingV3 as YieldFarming;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwap::LiquidityToken;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapGovPoolType::{PoolTypeFarmPool};
    use SwapAdmin::VToken::{VToken, Self};
    use SwapAdmin::VESTAR::{VESTAR};
    use SwapAdmin::TokenSwapBoost;


    const ERR_FARM_PARAM_ERROR: u64 = 101;

    const DEFAULT_BOOST_FACTOR: u64 = 1;
    // user boost factor section is [1,2.5]
    const BOOST_FACTOR_PRECESION: u64 = 100; //two-digit precision

    /// Event emitted when farm been added
    struct AddFarmEvent has drop, store {
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        /// signer of farm add
        signer: address,
        /// admin address
        admin: address,
    }

    /// Event emitted when farm been added
    struct ActivationStateEvent has drop, store {
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        /// signer of farm add
        signer: address,
        /// admin address
        admin: address,
        /// Activation state
        activation_state: bool,
    }

    /// Event emitted when stake been called
    struct StakeEvent has drop, store {
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        /// signer of stake user
        signer: address,
        // value of stake user
        amount: u128,
        /// admin address
        admin: address,
    }

    /// Event emitted when unstake been called
    struct UnstakeEvent has drop, store {
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        /// signer of stake user
        signer: address,
        /// admin address
        admin: address,
    }

    struct FarmPoolEvent has key, store {
        add_farm_event_handler: Event::EventHandle<AddFarmEvent>,
        activation_state_event_handler: Event::EventHandle<ActivationStateEvent>,
        stake_event_handler: Event::EventHandle<StakeEvent>,
        unstake_event_handler: Event::EventHandle<UnstakeEvent>,
    }

    struct FarmPoolCapability<phantom X, phantom Y> has key, store {
        cap: YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>,
        release_per_seconds: u128,
        //abandoned fields
    }

    struct FarmMultiplier<phantom X, phantom Y> has key, store {
        multiplier: u64,
    }

    struct FarmPoolStake<phantom X, phantom Y> has key, store {
        id: u64,
        /// Harvest capability for Farm
        cap: YieldFarming::HarvestCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>,
    }


    struct FarmPoolInfo<phantom X, phantom Y> has key, store {
        alloc_point: u128
    }

    struct UserInfo<phantom X, phantom Y> has key, store {
        boost_factor: u64,
        locked_vetoken: VToken<VESTAR>,
        user_amount: u128,
    }

    /// Initialize farm big pool
    public fun initialize_farm_pool(account: &signer, token: Token::Token<STAR::STAR>) {
        YieldFarming::initialize<PoolTypeFarmPool, STAR::STAR>(account, token);

        move_to(account, FarmPoolEvent{
            add_farm_event_handler: Event::new_event_handle<AddFarmEvent>(account),
            activation_state_event_handler: Event::new_event_handle<ActivationStateEvent>(account),
            stake_event_handler: Event::new_event_handle<StakeEvent>(account),
            unstake_event_handler: Event::new_event_handle<UnstakeEvent>(account),
        });
    }

    /// Called by admin
    /// this will config yield farming global pool info
    public fun initialize_global_pool_info(account: &signer, pool_release_per_second: u128) {
        // Only called by the genesis
        STAR::assert_genesis_address(account);
        YieldFarming::initialize_global_pool_info<PoolTypeFarmPool>(account, pool_release_per_second);
    }

    /// Deprecated call
    /// Initialize Liquidity pair gov pool, only called by token issuer
    public fun add_farm<X: copy + drop + store,
                        Y: copy + drop + store>(
        signer: &signer,
        release_per_seconds: u128) acquires FarmPoolEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        // To determine how many amount release in every period
        let cap = YieldFarming::add_asset<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(
            signer,
            release_per_seconds,
            0);

        move_to(signer, FarmPoolCapability<X, Y>{
            cap,
            release_per_seconds,
        });

        move_to(signer, FarmMultiplier<X, Y>{
            multiplier: 1
        });

        // Emit add farm event
        let admin = Signer::address_of(signer);
        let farm_pool_event = borrow_global_mut<FarmPoolEvent>(admin);
        Event::emit_event(&mut farm_pool_event.add_farm_event_handler,
            AddFarmEvent{
                y_token_code: Token::token_code<X>(),
                x_token_code: Token::token_code<Y>(),
                signer: Signer::address_of(signer),
                admin,
            });
    }


    /// Initialize Liquidity pair gov pool, only called by token issuer
    public fun add_farm_v2<X: copy + drop + store,
                           Y: copy + drop + store>(
        signer: &signer,
        alloc_point: u128) acquires FarmPoolEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        // To determine how many amount release in every period
        let cap = YieldFarming::add_asset_v2<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(
            signer,
            alloc_point,
            0);

        move_to(signer, FarmPoolCapability<X, Y>{
            cap,
            release_per_seconds: 0, //abandoned fields
        });

        move_to(signer, FarmPoolInfo<X, Y>{
            alloc_point: alloc_point
        });

        // Emit add farm event
        let admin = Signer::address_of(signer);
        let farm_pool_event = borrow_global_mut<FarmPoolEvent>(admin);
        Event::emit_event(&mut farm_pool_event.add_farm_event_handler,
            AddFarmEvent{
                y_token_code: Token::token_code<X>(),
                x_token_code: Token::token_code<Y>(),
                signer: Signer::address_of(signer),
                admin,
            });
    }


    /// call only for extend
    public fun extend_farm_pool<X: copy + drop + store,
                                 Y: copy + drop + store>(account: &signer, override_update: bool) acquires FarmMultiplier, FarmPoolInfo{
        STAR::assert_genesis_address(account);

        let broker = Signer::address_of(account);
        let farm_multiplier = borrow_global<FarmMultiplier<X, Y>>(broker);
        let alloc_point = (farm_multiplier.multiplier as u128);
        YieldFarming::extend_farming_asset<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account, alloc_point, override_update);

        if(!exists<FarmPoolInfo<X, Y>>(broker)){
            move_to(account, FarmPoolInfo<X, Y>{
                alloc_point: alloc_point
            });
        }else {
            let farm_pool_info = borrow_global_mut<FarmPoolInfo<X, Y>>(broker);
            farm_pool_info.alloc_point = alloc_point;
        };
    }


    /// Deprecated call
    /// Set farm mutiplier of second per releasing
    public fun set_farm_multiplier<X: copy + drop + store,
                                   Y: copy + drop + store>(signer: &signer, multiplier: u64)
    acquires FarmPoolCapability, FarmMultiplier {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let broker = Signer::address_of(signer);
        let cap = borrow_global<FarmPoolCapability<X, Y>>(broker);
        let farm_mult = borrow_global_mut<FarmMultiplier<X, Y>>(broker);

        let (alive, _, _, _, ) =
            YieldFarming::query_info<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(broker);

        let relese_per_sec_mul = cap.release_per_seconds * (multiplier as u128);
        YieldFarming::modify_parameter<PoolTypeFarmPool, STAR::STAR, Token::Token<LiquidityToken<X, Y>>>(
            &cap.cap,
            broker,
            relese_per_sec_mul,
            alive,
        );
        farm_mult.multiplier = multiplier;
    }

    /// Get farm multiplier of second per releasing
    public fun get_farm_multiplier<X: copy + drop + store,
                                   Y: copy + drop + store>(): u64 acquires FarmMultiplier, FarmPoolInfo {
        if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()){
            let farm_mult = borrow_global_mut<FarmMultiplier<X, Y>>(STAR::token_address());
            farm_mult.multiplier
            // Get farm mutiplier, equals to pool alloc_point
        } else {
            let farm_pool_info = borrow_global<FarmPoolInfo<X, Y>>(STAR::token_address());
            (farm_pool_info.alloc_point as u64)
        }
    }


    public fun set_farm_alloc_point<X: copy + drop + store,
                                    Y: copy + drop + store>(signer: &signer, alloc_point: u128)
    acquires FarmPoolCapability, FarmPoolInfo {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let broker = Signer::address_of(signer);
        let cap = borrow_global<FarmPoolCapability<X, Y>>(broker);
        let farm_pool_info = borrow_global_mut<FarmPoolInfo<X, Y>>(broker);

        YieldFarming::update_pool<PoolTypeFarmPool, STAR::STAR, Token::Token<LiquidityToken<X, Y>>>(
            &cap.cap,
            broker,
            alloc_point,
            farm_pool_info.alloc_point,
        );
        farm_pool_info.alloc_point = alloc_point;
    }

    /// Deprecated call
    /// Reset activation of farm from token type X and Y
    public fun reset_farm_activation<X: copy + drop + store, Y: copy + drop + store>(
        account: &signer,
        active: bool) acquires FarmPoolEvent, FarmPoolCapability {
        STAR::assert_genesis_address(account);
        let admin_addr = Signer::address_of(account);
        let cap = borrow_global_mut<FarmPoolCapability<X, Y>>(admin_addr);

        YieldFarming::modify_parameter<
            PoolTypeFarmPool,
            STAR::STAR,
            Token::Token<LiquidityToken<X, Y>>
        >(
            &cap.cap,
            admin_addr,
            cap.release_per_seconds,
            active,
        );

        let farm_pool_event = borrow_global_mut<FarmPoolEvent>(admin_addr);
        Event::emit_event(&mut farm_pool_event.activation_state_event_handler,
            ActivationStateEvent{
                y_token_code: Token::token_code<X>(),
                x_token_code: Token::token_code<Y>(),
                signer: Signer::address_of(account),
                admin: admin_addr,
                activation_state: active,
            });
    }

    //Deposit Token into the pool
    public fun deposit<PoolType: store, TokenT: copy + drop + store>(
        account: &signer,
        token: Token::Token<TokenT>) {
        YieldFarming::deposit<PoolType, TokenT>(account, token);
    }

    //View Treasury Remaining
    public fun get_treasury_balance<PoolType: store, TokenT: copy + drop + store>(): u128 {
        YieldFarming::get_treasury_balance<PoolType, TokenT>(STAR::token_address())
    }

    /// Stake liquidity Token pair
    public fun stake<X: copy + drop + store,
                     Y: copy + drop + store>(account: &signer,
                                             amount: u128)
    acquires FarmPoolCapability, FarmPoolEvent, FarmPoolStake, UserInfo {
        TokenSwapConfig::assert_global_freeze();

        let account_addr = Signer::address_of(account);
        if (!Account::is_accept_token<STAR::STAR>(account_addr)) {
            Account::do_accept_token<STAR::STAR>(account);
        };

        // after pool alloc mode upgrade
        if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            //check if need extend
            if (YieldFarming::exists_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr) &&
                (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr))) {
                extend_farm_stake_resource<X, Y>(account);
            };
        };

        // Actual stake
        let farm_cap = borrow_global_mut<FarmPoolCapability<X, Y>>(STAR::token_address());
        let harvest_cap = inner_stake<X, Y>(account, amount, farm_cap);

        // Store a capability to account
        move_to(account, harvest_cap);

        // Emit stake event
        let farm_stake_event = borrow_global_mut<FarmPoolEvent>(STAR::token_address());
        Event::emit_event(&mut farm_stake_event.stake_event_handler,
            StakeEvent{
                y_token_code: Token::token_code<X>(),
                x_token_code: Token::token_code<Y>(),
                signer: account_addr,
                admin: STAR::token_address(),
                amount,
            });
    }

    fun extend_farm_stake_resource<X: copy + drop + store,
                                   Y: copy + drop + store>(account: &signer)
    acquires FarmPoolCapability {
        let account_addr = Signer::address_of(account);
        //double check if need extend
        if (!(YieldFarming::exists_stake_at_address<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr) &&
              (!YieldFarming::exists_stake_extend<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr)))) {
            return
        };

        // Access Control
        let farm_cap = borrow_global_mut<FarmPoolCapability<X, Y>>(STAR::token_address());

        let stake_ids = YieldFarming::query_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr);
        let len = Vector::length(&stake_ids);
        let idx = 0;
        loop {
            if (idx >= len) {
                break
            };
            let stake_id = Vector::borrow(&stake_ids, idx);
            YieldFarming::extend_farm_stake_info<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account, *stake_id, &farm_cap.cap);

            idx = idx + 1;
        }
    }


    public fun get_default_boost_factor_scale(): u64 {
        DEFAULT_BOOST_FACTOR * BOOST_FACTOR_PRECESION
    }


    /// Unstake liquidity Token pair
    public fun unstake<X: copy + drop + store,
                       Y: copy + drop + store>(account: &signer, amount: u128)
    acquires FarmPoolCapability, FarmPoolStake, FarmPoolEvent, UserInfo {
        TokenSwapConfig::assert_global_freeze();

        let account_addr = Signer::address_of(account);
        // after pool alloc mode upgrade
        if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            //check if need extend
            if (YieldFarming::exists_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr) &&
                (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr))) {
                extend_farm_stake_resource<X, Y>(account);
            };
        };

        // Actual stake
        let farm_cap = borrow_global_mut<FarmPoolCapability<X, Y>>(STAR::token_address());
        let farm_stake = move_from<FarmPoolStake<X, Y>>(account_addr);
        let harvest_cap = inner_unstake<X, Y>(account, amount, farm_cap, farm_stake);

        move_to(account, harvest_cap);

        // Emit unstake event
        let farm_stake_event = borrow_global_mut<FarmPoolEvent>(STAR::token_address());
        Event::emit_event(&mut farm_stake_event.unstake_event_handler,
            UnstakeEvent{
                y_token_code: Token::token_code<X>(),
                x_token_code: Token::token_code<Y>(),
                signer: account_addr,
                admin: STAR::token_address(),
            });
    }

    /// Harvest reward from token pool
    public fun harvest<X: copy + drop + store,
                       Y: copy + drop + store>(account: &signer, amount: u128) acquires FarmPoolStake, FarmPoolCapability {
        TokenSwapConfig::assert_global_freeze();

        let account_addr = Signer::address_of(account);
        // after pool alloc mode upgrade
        if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            //check if need extend
            if (YieldFarming::exists_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr) &&
                (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr))) {
                extend_farm_stake_resource<X, Y>(account);
            };
        };

        let farm_harvest_cap = borrow_global_mut<FarmPoolStake<X, Y>>(account_addr);
        let token = YieldFarming::harvest<
            PoolTypeFarmPool,
            STAR::STAR,
            Token::Token<LiquidityToken<X, Y>>>(
            account_addr,
            STAR::token_address(),
            amount,
            &farm_harvest_cap.cap,
        );
        Account::deposit<STAR::STAR>(account_addr, token);
    }

    /// Return calculated APY
    public fun lookup_gain<X: copy + drop + store, Y: copy + drop + store>(account: address): u128 acquires FarmPoolStake {
        let farm = borrow_global<FarmPoolStake<X, Y>>(account);
        YieldFarming::query_expect_gain<PoolTypeFarmPool, STAR::STAR, Token::Token<LiquidityToken<X, Y>>>(
            account, STAR::token_address(), &farm.cap)
    }

    /// Query all stake info
    public fun query_info<X: copy + drop + store, Y: copy + drop + store>(): (bool, u128, u128, u128) {
        YieldFarming::query_info<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(STAR::token_address())
    }

    /// Query pool info from pool type v2
    /// return value: (alloc_point, asset_total_amount, asset_total_weight, harvest_index)
    public fun query_info_v2<X: copy + drop + store, Y: copy + drop + store>(): (u128, u128, u128, u128) {
        YieldFarming::query_pool_info_v2<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(STAR::token_address())
    }

    /// Query all stake amount
    public fun query_total_stake<X: copy + drop + store, Y: copy + drop + store>(): u128 {
        YieldFarming::query_total_stake<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(STAR::token_address())
    }

    /// Query stake amount from user
    public fun query_stake<X: copy + drop + store, Y: copy + drop + store>(account: address): u128 acquires FarmPoolStake {
        let farm = borrow_global<FarmPoolStake<X, Y>>(account);
        YieldFarming::query_stake<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account, farm.id)
    }

    /// Query release per second
    public fun query_release_per_second<X: copy + drop + store, Y: copy + drop + store>(): u128 acquires FarmPoolCapability, FarmPoolInfo {
        if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()){
            let cap = borrow_global<FarmPoolCapability<X, Y>>(STAR::token_address());
            cap.release_per_seconds
        } else {
            let farm_pool_info = borrow_global<FarmPoolInfo<X, Y>>(STAR::token_address());
            let (total_alloc_point, pool_release_per_second) = YieldFarming::query_global_pool_info<PoolTypeFarmPool>(STAR::token_address());
            pool_release_per_second * farm_pool_info.alloc_point / total_alloc_point
        }
    }

    /// Query farm golbal pool info
    public fun query_global_pool_info(): (u128, u128) {
        let (total_alloc_point, pool_release_per_second) = YieldFarming::query_global_pool_info<PoolTypeFarmPool>(STAR::token_address());
        (total_alloc_point, pool_release_per_second)
    }


    /// Inner stake operation that unstake all from pool and combind new amount to total asset, then restake.
    fun inner_stake<X: copy + drop + store,
                    Y: copy + drop + store>(account: &signer,
                                            amount: u128,
                                            farm_cap: &FarmPoolCapability<X, Y>)
    : FarmPoolStake<X, Y> acquires FarmPoolStake ,UserInfo{
        let account_addr = Signer::address_of(account);
        // If stake exist, unstake all withdraw staking, and set reward token to buffer pool
        let own_token = if (YieldFarming::exists_stake_at_address<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr)) {
            let FarmPoolStake<X, Y>{
                id: _,
                cap : unwrap_harvest_cap
            } = move_from<FarmPoolStake<X, Y>>(account_addr);

            // Unstake all liquidity token and reward token
            let (own_token, reward_token) = YieldFarming::unstake<
                PoolTypeFarmPool,
                STAR::STAR,
                Token::Token<LiquidityToken<X, Y>>
            >(account, STAR::token_address(), unwrap_harvest_cap);
            Account::deposit<STAR::STAR>(account_addr, reward_token);
            own_token
        } else {
            Token::zero<LiquidityToken<X, Y>>()
        };


        // Withdraw addtion token. Addtionally, combine addtion token and own token.
        let addition_token = TokenSwapRouter::withdraw_liquidity_token<X, Y>(account, amount);
        let total_token = Token::join<LiquidityToken<X, Y>>(own_token, addition_token);
        let total_amount = Token::value<LiquidityToken<X, Y>>(&total_token);


        // after pool alloc mode upgrade
        let (new_harvest_cap, stake_id) = if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            YieldFarming::stake<
                PoolTypeFarmPool,
                STAR::STAR,
                Token::Token<LiquidityToken<X, Y>>>(
                account,
                STAR::token_address(),
                total_token,
                total_amount,
                1,
                0,
                &farm_cap.cap
            )
        } else {
            let weight_factor = get_boost_factor<X, Y>(account_addr);
            let asset_weight = calculate_boost_weight(total_amount, weight_factor);

            YieldFarming::stake_v2<
                PoolTypeFarmPool,
                STAR::STAR,
                Token::Token<LiquidityToken<X, Y>>>(
                account,
                STAR::token_address(),
                total_token,
                asset_weight,
                total_amount,
                weight_factor,
                0,
                &farm_cap.cap
            )
        };

        FarmPoolStake<X, Y>{
            cap: new_harvest_cap,
            id: stake_id,
        }
    }

    /// Inner unstake operation that unstake all from pool and combind new amount to total asset, then restake.
    fun inner_unstake<X: copy + drop + store,
                      Y: copy + drop + store>(account: &signer,
                                              amount: u128,
                                              farm_cap: &FarmPoolCapability<X, Y>,
                                              farm_stake: FarmPoolStake<X, Y>)
    : FarmPoolStake<X, Y> acquires  UserInfo{
        let account_addr = Signer::address_of(account);
        let FarmPoolStake{
            cap: unwrap_harvest_cap,
            id: _,
        } = farm_stake;
        assert!(amount > 0, Errors::invalid_state(ERR_FARM_PARAM_ERROR));

        // unstake all from pool
        let (own_asset_token, reward_token) = YieldFarming::unstake<
            PoolTypeFarmPool,
            STAR::STAR,
            Token::Token<LiquidityToken<X, Y>>
        >(account, STAR::token_address(), unwrap_harvest_cap);

        // Process reward token
        Account::deposit<STAR::STAR>(account_addr, reward_token);

        // Process asset token
        let withdraw_asset_token = Token::withdraw<LiquidityToken<X, Y>>(&mut own_asset_token, amount);
        TokenSwapRouter::deposit_liquidity_token<X, Y>(account_addr, withdraw_asset_token);

        let own_asset_amount = Token::value<LiquidityToken<X, Y>>(&own_asset_token);

        // Restake to pool
        // after pool alloc mode upgrade
        let (new_harvest_cap, stake_id) = if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            YieldFarming::stake<
                PoolTypeFarmPool,
                STAR::STAR,
                Token::Token<LiquidityToken<X, Y>>>(
                account,
                STAR::token_address(),
                own_asset_token,
                own_asset_amount,
                1,
                0,
                &farm_cap.cap
            )
        } else {
            // once farm unstake, user boost factor lose efficacy, become 1
            unboost_for_unstake<X, Y>(account);
            let weight_factor = get_boost_factor<X, Y>(account_addr);
            let own_asset_weight = calculate_boost_weight(own_asset_amount, weight_factor);
            YieldFarming::stake_v2<
                PoolTypeFarmPool,
                STAR::STAR,
                Token::Token<LiquidityToken<X, Y>>>(
                account,
                STAR::token_address(),
                own_asset_token,
                own_asset_weight,
                own_asset_amount,
                weight_factor,
                0,
                &farm_cap.cap
            )
        };

        FarmPoolStake<X, Y>{
            cap: new_harvest_cap,
            id: stake_id,
        }
    }

    /// Query user boost factor
    public fun get_boost_factor<X: copy + drop + store, Y: copy + drop + store>(account: address): u64 acquires UserInfo {
        if(exists<UserInfo<X, Y>>(account)){
            let user_info = borrow_global<UserInfo<X, Y>>(account);
            user_info.boost_factor
        } else {
            get_default_boost_factor_scale()
        }
    }

    /// calculation asset weight for boost
    fun calculate_boost_weight(amount: u128, boost_factor: u64): u128 {
        amount * (boost_factor as u128) / (BOOST_FACTOR_PRECESION as u128)
    }

    /// boost for farm
    public fun boost<X: copy + drop + store, Y: copy + drop + store>(account: &signer, boost_amount: u128)
    acquires UserInfo, FarmPoolStake, FarmPoolCapability {
        let user_addr = Signer::address_of(account);
        if(!exists<UserInfo<X, Y>>(user_addr)){
            move_to(account, UserInfo<X, Y>{
                user_amount: 0,
                boost_factor: get_default_boost_factor_scale(),
                locked_vetoken: VToken::zero<VESTAR>(),
            });
        };
        let user_info = borrow_global_mut<UserInfo<X, Y>>(user_addr);
        //TODO lock boost amount vestar
//        let boost_vestar_token = TokenSwapBoost::lock_vestar();
        let boost_vestar_token = Token::zero<VESTAR>();

        VToken::deposit(&mut user_info.locked_vetoken, boost_vestar_token);
        update_boost_factor<X, Y>(account);
    }

    /// unboost for farm unstake
    public fun unboost_for_unstake<X: copy + drop + store, Y: copy + drop + store>(account: &signer)
    acquires UserInfo {
        let user_addr = Signer::address_of(account);
        if(!exists<UserInfo<X, Y>>(user_addr)){
            move_to(account, UserInfo<X, Y>{
                user_amount: 0,
                boost_factor: get_default_boost_factor_scale(),
                locked_vetoken: VToken::zero<VESTAR>(),
            });
        };
        let user_info = borrow_global_mut<UserInfo<X, Y>>(user_addr);
        //TODO unlock boost amount vestar
//        let boost_vestar_token = TokenSwapBoost::unlock_vestar();
//        let boost_vestar_token = TOken::zero<VESTAR>();

//        VToken::deposit(&mut user_info.locked_vetoken, boost_vestar_token);
        user_info.boost_factor = get_default_boost_factor_scale(); // reset to 1
    }

    /// boost factor change and triggers
    fun update_boost_factor<X: copy + drop + store, Y: copy + drop + store>(
        account: &signer,
    ) acquires  UserInfo, FarmPoolStake, FarmPoolCapability {
        let user_addr = Signer::address_of(account);

        let user_info = borrow_global_mut<UserInfo<X, Y>>(user_addr);
        let total_locked_vetoken_amount = VToken::value<VESTAR>(&user_info.locked_vetoken);
        let new_boost_factor = TokenSwapBoost::compute_boost_factor(total_locked_vetoken_amount);

        let farm = borrow_global<FarmPoolStake<X, Y>>(user_addr);
        let asset_amount = YieldFarming::query_stake<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(user_addr, farm.id);

        let new_asset_weight = calculate_boost_weight(asset_amount, new_boost_factor);
        let last_asset_weight = calculate_boost_weight(asset_amount, user_info.boost_factor);
        update_pool_and_stake_weight<X, Y>(account, new_boost_factor, new_asset_weight, last_asset_weight);

        user_info.boost_factor = new_boost_factor;

    }

    fun update_pool_and_stake_weight<X: copy + drop + store, Y: copy + drop + store>(
        account: &signer,
        new_weight_factor: u64, //new stake weight factor
        new_asset_weight: u128, //new stake asset weight
        last_asset_weight: u128, //last stake asset weight)
    ) acquires FarmPoolCapability, FarmPoolStake {
        let account_addr = Signer::address_of(account);
        // Access Control
        let farm_cap = borrow_global_mut<FarmPoolCapability<X, Y>>(STAR::token_address());

        let farm = borrow_global<FarmPoolStake<X, Y>>(account_addr);

        // check if need udpate
//        if (farm.id > 0){
            YieldFarming::update_pool_weight<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(&farm_cap.cap,
                STAR::token_address(), new_asset_weight, last_asset_weight);
            YieldFarming::update_pool_stake_weight<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(&farm_cap.cap,
                STAR::token_address(), account_addr, farm.id, new_weight_factor, new_asset_weight, last_asset_weight);
//        };

    }


}
}