// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address 0x4783d08fb16990bd35d83f3e23bf93b8 {

module YieldFarmingV3 {
    use 0x1::Token;
    use 0x1::Signer;
    use 0x1::Timestamp;
    use 0x1::Errors;
    use 0x1::Math;
    use 0x1::Option;
    use 0x1::Vector;
    use 0x1::Debug;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::BigExponential;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::YieldFarmingLibrary;

    const ERR_FARMING_INIT_REPEATE: u64 = 101;
    const ERR_FARMING_NOT_READY: u64 = 102;
    const ERR_FARMING_STAKE_EXISTS: u64 = 103;
    const ERR_FARMING_STAKE_NOT_EXISTS: u64 = 104;
    const ERR_FARMING_HAVERST_NO_GAIN: u64 = 105;
    const ERR_FARMING_TOTAL_WEIGHT_IS_ZERO: u64 = 106;
    const ERR_FARMING_BALANCE_EXCEEDED: u64 = 108;
    const ERR_FARMING_NOT_ENOUGH_ASSET: u64 = 109;
    const ERR_FARMING_TIMESTAMP_INVALID: u64 = 110;
    const ERR_FARMING_TOKEN_SCALE_OVERFLOW: u64 = 111;
    const ERR_FARMING_CALC_LAST_IDX_BIGGER_THAN_NOW: u64 = 112;
    const ERR_FARMING_NOT_ALIVE: u64 = 113;
    const ERR_FARMING_ALIVE_STATE_INVALID: u64 = 114;
    const ERR_FARMING_ASSET_NOT_EXISTS: u64 = 115;
    const ERR_FARMING_STAKE_INDEX_ERROR: u64 = 116;
    const ERR_FARMING_MULTIPLIER_OVERFLOW: u64 = 117;
    const ERR_FARMING_OPT_AFTER_DEADLINE: u64 = 118;

    /// The object of yield farming
    /// RewardTokenT meaning token of yield farming
    struct Farming<PoolType, RewardTokenT> has key, store {
        treasury_token: Token::Token<RewardTokenT>,
    }

    struct FarmingAsset<PoolType, AssetT> has key, store {
        asset_total_weight: u128,
        harvest_index: u128,
        last_update_timestamp: u64,
        // Release count per seconds
        release_per_second: u128,
        // Start time, by seconds, user can operate stake only after this timestamp
        start_time: u64,
        // Representing the pool is alive, false: not alive, true: alive.
        alive: bool,
    }

    /// To store user's asset token
    struct Stake<PoolType, AssetT> has store, copy, drop {
        id: u64,
        asset: AssetT,
        asset_weight: u128,
        last_harvest_index: u128,
        gain: u128,
        asset_multiplier: u64,
    }

    struct StakeList<PoolType, AssetT> has key, store {
        next_id: u64,
        items: vector<Stake<PoolType, AssetT>>,
    }

    /// Capability to modify parameter such as period and release amount
    struct ParameterModifyCapability<PoolType, AssetT> has key, store {}

    /// Harvest ability to harvest
    struct HarvestCapability<PoolType, AssetT> has key, store {
        stake_id: u64,
        // Indicates the deadline from start_time for the current harvesting permission,
        // which meaning a timestamp, by seconds
        deadline: u64,
    }

    /// Called by token issuer
    /// this will declare a yield farming pool
    public fun initialize<
        PoolType: store,
        RewardTokenT: store>(account: &signer, treasury_token: Token::Token<RewardTokenT>) {
        let scaling_factor = Math::pow(10, BigExponential::exp_scale_limition());
        let token_scale = Token::scaling_factor<RewardTokenT>();
        assert(token_scale <= scaling_factor, Errors::limit_exceeded(ERR_FARMING_TOKEN_SCALE_OVERFLOW));
        assert(!exists_at<PoolType, RewardTokenT>(Signer::address_of(account)), Errors::invalid_state(ERR_FARMING_INIT_REPEATE));

        move_to(account, Farming<PoolType, RewardTokenT>{
            treasury_token,
        });
    }

    /// Add asset pools
    public fun add_asset<PoolType: store, AssetT: store>(
        account: &signer,
        release_per_second: u128,
        delay: u64): ParameterModifyCapability<PoolType, AssetT> {
        assert(
            !exists_asset_at<PoolType, AssetT>(Signer::address_of(account)),
            Errors::invalid_state(ERR_FARMING_INIT_REPEATE)
        );

        let now_seconds = Timestamp::now_seconds();

        move_to(account, FarmingAsset<PoolType, AssetT>{
            asset_total_weight: 0,
            harvest_index: 0,
            last_update_timestamp: now_seconds,
            release_per_second,
            start_time: now_seconds + delay,
            alive: true
        });
        ParameterModifyCapability<PoolType, AssetT> {}
    }

    /// Remove asset for make this pool to the state of not alive
    /// Please make sure all user unstaking from this pool
    //    public fun remove_asset<PoolType: store, AssetT: store>(
    //        broker: address,
    //        cap: ParameterModifyCapability) acquires FarmingAsset {
    //        let ParameterModifyCapability {} = cap;
    //        let FarmingAsset<PoolType, AssetT> {
    //            asset_total_weight: _,
    //            harvest_index: _,
    //            last_update_timestamp: _,
    //            release_per_second: _,
    //            start_time: _,
    //            alive: _,
    //        } = move_from<FarmingAsset<PoolType, AssetT>>(broker);
    //    }

    public fun modify_parameter<PoolType: store, RewardTokenT: store, AssetT: store>(
        _cap: &ParameterModifyCapability<PoolType, AssetT>,
        broker: address,
        release_per_second: u128,
        alive: bool) acquires FarmingAsset {
        // Not support to shuttingdown alive state.
        assert(alive, Errors::invalid_state(ERR_FARMING_ALIVE_STATE_INVALID));
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        // assert(farming_asset.alive != alive, Errors::invalid_state(ERR_FARMING_ALIVE_STATE_INVALID));

        let now_seconds = Timestamp::now_seconds();
        farming_asset.last_update_timestamp = now_seconds;

        // if the pool is alive, then update index
        if (farming_asset.alive) {
            farming_asset.harvest_index =
                calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds);
        };

        farming_asset.release_per_second = release_per_second;
        farming_asset.alive = alive;
    }

    /// Call by stake user, staking amount of asset in order to get yield farming token
    public fun stake<PoolType: store, RewardTokenT: store, AssetT: store>(
        signer: &signer,
        broker_addr: address,
        asset: AssetT,
        asset_weight: u128,
        asset_multiplier: u64,
        deadline: u64,
        _cap: &ParameterModifyCapability<PoolType, AssetT>) : (HarvestCapability<PoolType, AssetT>, u64)
    acquires StakeList, FarmingAsset {
        assert(exists_asset_at<PoolType, AssetT>(broker_addr), Errors::invalid_state(ERR_FARMING_ASSET_NOT_EXISTS));
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker_addr);
        let now_seconds = Timestamp::now_seconds();

        intra_pool_state_check<PoolType, AssetT>(now_seconds, farming_asset);

        let user_addr = Signer::address_of(signer);
        if (!exists<StakeList<PoolType, AssetT>>(user_addr)) {
            move_to(signer, StakeList<PoolType, AssetT>{
                next_id: 0,
                items: Vector::empty<Stake<PoolType, AssetT>>(),
            });
        };

        let (harvest_index, total_asset_weight, gain) = if (farming_asset.asset_total_weight <= 0) {
            let time_period = now_seconds - farming_asset.last_update_timestamp;
            (
                0,
                asset_weight * (asset_multiplier as u128),
                farming_asset.release_per_second * (time_period as u128)
            )
        } else {
            (
                calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds),
                farming_asset.asset_total_weight + (asset_weight * (asset_multiplier as u128)),
                0
            )
        };

        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
        let stake_id = stake_list.next_id + 1;
        Vector::push_back<Stake<PoolType, AssetT>>(&mut stake_list.items, Stake<PoolType, AssetT>{
            id: stake_id,
            asset,
            asset_weight,
            last_harvest_index: harvest_index,
            gain,
            asset_multiplier,
        });

        farming_asset.harvest_index = harvest_index;
        farming_asset.asset_total_weight = total_asset_weight;
        farming_asset.last_update_timestamp = now_seconds;

        stake_list.next_id = stake_id;

        // Normalize deadline
        deadline = if (deadline > 0) {
            deadline + now_seconds
        } else {
            0
        };

        // Return values
        (
            HarvestCapability<PoolType, AssetT>{
                stake_id,
                deadline,
            },
            stake_id,
        )
    }

    /// Unstake asset from farming pool
    public fun unstake<PoolType: store, RewardTokenT: store, AssetT: store>(
        signer: &signer,
        broker: address,
        cap: HarvestCapability<PoolType, AssetT>)
    : (AssetT, Token::Token<RewardTokenT>) acquires Farming, FarmingAsset, StakeList {
        // Destroy capability
        let HarvestCapability<PoolType, AssetT>{ stake_id, deadline } = cap;

        let farming = borrow_global_mut<Farming<PoolType, RewardTokenT>>(broker);
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        let now_seconds = Timestamp::now_seconds();

        intra_pool_state_check<PoolType, AssetT>(now_seconds, farming_asset);

        let items = borrow_global_mut<StakeList<PoolType, AssetT>>(Signer::address_of(signer));

        let Stake<PoolType, AssetT>{
            id: out_stake_id,
            asset: staked_asset,
            asset_weight: staked_asset_weight,
            last_harvest_index: staked_latest_harvest_index,
            gain: staked_gain,
            asset_multiplier: staked_asset_multiplier,
        } = pop_stake<PoolType, AssetT>(&mut items.items, stake_id);

        assert(stake_id == out_stake_id, Errors::invalid_state(ERR_FARMING_STAKE_INDEX_ERROR));

        let now_seconds = intra_query_maybe_deadline(now_seconds, deadline, true);

        let new_harvest_index = calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds);

        let asset_weight = staked_asset_weight * (staked_asset_multiplier as u128);
        let period_gain = YieldFarmingLibrary::calculate_withdraw_amount(
            new_harvest_index,
            staked_latest_harvest_index,
            asset_weight,
        );

        let withdraw_token = Token::withdraw<RewardTokenT>(&mut farming.treasury_token, staked_gain + period_gain);
        assert(farming_asset.asset_total_weight >= asset_weight, Errors::invalid_state(ERR_FARMING_NOT_ENOUGH_ASSET));

        // Update farm asset
        farming_asset.asset_total_weight = farming_asset.asset_total_weight - asset_weight;

        // if `now_seconds` less than pool's `last_update_timestamp`, it's `deadline`, otherwise now timestamp
        // We don't update `last_update_timestamp` if `now_seconds` < `farming_asset.last_update_timestamp`
        // because the latter has updated by others before this code execute.
        if (now_seconds > farming_asset.last_update_timestamp) {
            farming_asset.last_update_timestamp = now_seconds;

            if (farming_asset.alive) {
                farming_asset.harvest_index = new_harvest_index;
            };
        };

        (staked_asset, withdraw_token)
    }

    /// Harvest yield farming token from stake
    public fun harvest<PoolType: store,
                       RewardTokenT: store,
                       AssetT: store>(
        user_addr: address,
        broker_addr: address,
        amount: u128,
        cap: &HarvestCapability<PoolType, AssetT>): Token::Token<RewardTokenT> acquires Farming, FarmingAsset, StakeList {
        let farming = borrow_global_mut<Farming<PoolType, RewardTokenT>>(broker_addr);
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker_addr);

        // Start check
        let now_seconds = Timestamp::now_seconds();
        intra_pool_state_check<PoolType, AssetT>(now_seconds, farming_asset);

        // Get stake from stake list
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
        let stake = get_stake<PoolType, AssetT>(&mut stake_list.items, cap.stake_id);

        now_seconds = intra_query_maybe_deadline(now_seconds, cap.deadline, true);

        let new_harvest_index = calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds);

        let asset_weight = stake.asset_weight * (stake.asset_multiplier as u128);
        let period_gain = YieldFarmingLibrary::calculate_withdraw_amount(
            new_harvest_index,
            stake.last_harvest_index,
            asset_weight,
        );

        let total_gain = stake.gain + period_gain;
        //assert(total_gain > 0, Errors::limit_exceeded(ERR_FARMING_HAVERST_NO_GAIN));
        assert(total_gain >= amount, Errors::limit_exceeded(ERR_FARMING_BALANCE_EXCEEDED));

        let withdraw_amount = if (amount <= 0) {
            total_gain
        } else {
            amount
        };

        Debug::print(&22222222);
        Debug::print(farming_asset);
        Debug::print(stake);
        Debug::print(&new_harvest_index);
        Debug::print(&period_gain);
        Debug::print(&now_seconds);
        Debug::print(&22222222);

        let withdraw_token = Token::withdraw<RewardTokenT>(&mut farming.treasury_token, withdraw_amount);
        stake.gain = total_gain - withdraw_amount;
        stake.last_harvest_index = new_harvest_index;

        // if `now_seconds` less than pool's `last_update_timestamp`, it's `deadline`, otherwise now timestamp
        // We don't update `last_update_timestamp` if `now_seconds` < `farming_asset.last_update_timestamp`
        // because the latter has updated by others before this code execute.
        if (now_seconds > farming_asset.last_update_timestamp) {
            farming_asset.last_update_timestamp = now_seconds;

            if (farming_asset.alive) {
                farming_asset.harvest_index = new_harvest_index;
            };
        };

        withdraw_token
    }

    /// The user can quering all yield farming amount in any time and scene
    public fun query_expect_gain<PoolType: store,
                                 RewardTokenT: store,
                                 AssetT: store>(user_addr: address,
                                                broker_addr: address,
                                                cap: &HarvestCapability<PoolType, AssetT>)
    : u128 acquires FarmingAsset, StakeList {
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker_addr);
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);

        // Start check
        let now_seconds = Timestamp::now_seconds();
        assert(now_seconds >= farming_asset.start_time, Errors::invalid_state(ERR_FARMING_NOT_READY));

        // Calculate new harvest index
        let now_seconds = intra_query_maybe_deadline(now_seconds, cap.deadline, false);
        let new_harvest_index = calculate_harvest_index_with_asset<PoolType, AssetT>(
            farming_asset,
            now_seconds
        );

        let stake = get_stake(&mut stake_list.items, cap.stake_id);
        let asset_weight = stake.asset_weight * (stake.asset_multiplier as u128);
        let new_gain = YieldFarmingLibrary::calculate_withdraw_amount(
            new_harvest_index,
            stake.last_harvest_index,
            asset_weight
        );

        Debug::print(&11111111);
        Debug::print(farming_asset);
        Debug::print(stake);
        Debug::print(&now_seconds);
        Debug::print(&new_harvest_index);
        Debug::print(&new_gain);
        Debug::print(&11111111);

        stake.gain + new_gain
    }

    /// Query total stake count from yield farming resource
    public fun query_total_stake<PoolType: store,
                                 AssetT: store>(broker: address): u128 acquires FarmingAsset {
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        farming_asset.asset_total_weight
    }

    /// Query stake weight from user staking objects.
    public fun query_stake<PoolType: store,
                           AssetT: store>(account: address, id: u64): u128 acquires StakeList {
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(account);
        let stake = get_stake(&mut stake_list.items, id);
        assert(stake.id == id, Errors::invalid_state(ERR_FARMING_STAKE_INDEX_ERROR));
        stake.asset_weight
    }

    /// Query stake id list from user
    public fun query_stake_list<PoolType: store,
                                AssetT: store>(user_addr: address): vector<u64> acquires StakeList {
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
        let len = Vector::length(&stake_list.items);
        if (len <= 0) {
            return Vector::empty<u64>()
        };

        let ret_list = Vector::empty<u64>();
        let idx = 0;
        loop {
            if (idx >= len) {
                break
            };
            let stake = Vector::borrow<Stake<PoolType, AssetT>>(&stake_list.items, idx);
            Vector::push_back(&mut ret_list, stake.id);
            idx = idx + 1;
        };
        ret_list
    }

    /// Queyry pool info from pool type
    /// return value: (alive, release_per_second, asset_total_weight, harvest_index)
    public fun query_info<PoolType: store, AssetT: store>(broker: address): (bool, u128, u128, u128) acquires FarmingAsset {
        let asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        (
            asset.alive,
            asset.release_per_second,
            asset.asset_total_weight,
            asset.harvest_index
        )
    }

    /// Update farming asset
    fun calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset: &FarmingAsset<PoolType, AssetT>,
                                                             now_seconds: u64): u128 {
        YieldFarmingLibrary::calculate_harvest_index_with_asse_info(
            farming_asset.asset_total_weight,
            farming_asset.harvest_index,
            farming_asset.last_update_timestamp,
            farming_asset.release_per_second,
            now_seconds
        )
    }

    /// This function may return a deadline timestamp if the deadline before now
    /// if deadline is valid.
    fun intra_query_maybe_deadline(now_seconds: u64, deadline: u64, assert_check: bool) : u64 {
        // Calculate end time, if deadline is less than now then `deadline`, otherwise `now`.
        if (deadline > 0) {
            if (assert_check) {
                assert(now_seconds > deadline, Errors::invalid_state(ERR_FARMING_OPT_AFTER_DEADLINE));
            };
            deadline
        } else {
            now_seconds
        }
    }

    /// Pool state check function
    fun intra_pool_state_check<PoolType: store,
                               AssetT: store>(now_seconds: u64,
                                              farming_asset: &FarmingAsset<PoolType, AssetT>) {
        // Check is alive
        assert(farming_asset.alive, Errors::invalid_state(ERR_FARMING_NOT_ALIVE));

        // Pool Start state check
        assert(now_seconds >= farming_asset.start_time, Errors::invalid_state(ERR_FARMING_NOT_READY));
    }

    fun find_idx_by_id<PoolType: store,
                       AssetType: store>(c: &vector<Stake<PoolType, AssetType>>, id: u64): Option::Option<u64> {
        let len = Vector::length(c);
        if (len == 0) {
            return Option::none()
        };
        let idx = len - 1;
        loop {
            let el = Vector::borrow(c, idx);
            if (el.id == id) {
                return Option::some(idx)
            };
            if (idx == 0) {
                return Option::none()
            };
            idx = idx - 1;
        }
    }

    fun get_stake<PoolType: store,
                  AssetType: store>(c: &mut vector<Stake<PoolType, AssetType>>, id: u64): &mut Stake<PoolType, AssetType> {
        let idx = find_idx_by_id<PoolType, AssetType>(c, id);
        assert(Option::is_some<u64>(&idx), Errors::invalid_state(ERR_FARMING_STAKE_NOT_EXISTS));
        Vector::borrow_mut<Stake<PoolType, AssetType>>(c, Option::destroy_some<u64>(idx))
    }

    fun pop_stake<PoolType: store,
                  AssetType: store>(c: &mut vector<Stake<PoolType, AssetType>>, id: u64): Stake<PoolType, AssetType> {
        let idx = find_idx_by_id<PoolType, AssetType>(c, id);
        assert(Option::is_some(&idx), Errors::invalid_state(ERR_FARMING_STAKE_NOT_EXISTS));
        Vector::remove<Stake<PoolType, AssetType>>(c, Option::destroy_some<u64>(idx))
    }

    /// Check the Farming of TokenT is exists.
    public fun exists_at<PoolType: store, RewardTokenT: store>(broker: address): bool {
        exists<Farming<PoolType, RewardTokenT>>(broker)
    }

    /// Check the Farming of AsssetT is exists.
    public fun exists_asset_at<PoolType: store, AssetT: store>(broker: address): bool {
        exists<FarmingAsset<PoolType, AssetT>>(broker)
    }
}
}