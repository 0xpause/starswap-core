//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use SwapAdmin::TokenMock::WETH;

    fun alice_accept_token(signer: signer) {
        Account::do_accept_token<WETH>(&signer);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;

    use SwapAdmin::TokenMock;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::STAR;

    fun admin_initialize(signer: signer) {
        TokenMock::register_token<STAR::STAR>(&signer, 9u8);
        TokenMock::register_token<TokenMock::WETH>(&signer, 9u8);

        let powed_mint_aount = CommonHelper::pow_amount<STAR::STAR>(100000000);

        // Initialize pool
        TokenSwapSyrup::initialize(&signer, TokenMock::mint_token<STAR::STAR>(powed_mint_aount));

        let release_per_second_amount = CommonHelper::pow_amount<TokenMock::WETH>(100);

        // Release 100 amount for one second
        TokenSwapSyrup::add_pool<TokenMock::WETH>(&signer, release_per_second_amount, 0);
        TokenSwapSyrup::set_alive<TokenMock::WETH>(&signer, true);

        let release_per_second = TokenSwapSyrup::query_release_per_second<TokenMock::WETH>();
        assert!(release_per_second == release_per_second_amount, 10001);
        assert!(TokenSwapSyrup::query_total_stake<TokenMock::WETH>() == 0, 10002);

        // Initialize asset such as WETH to alice's account
        CommonHelper::safe_mint<TokenMock::WETH>(&signer, powed_mint_aount);
        Account::deposit<TokenMock::WETH>(@alice, TokenMock::mint_token<TokenMock::WETH>(powed_mint_aount));
        assert!(Account::balance<TokenMock::WETH>(@alice) == powed_mint_aount, 10003);

        TokenSwapConfig::put_stepwise_multiplier(&signer, 1u64, 1u64);
        TokenSwapConfig::put_stepwise_multiplier(&signer, 2u64, 1u64);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Debug;

    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::CommonHelper;

    fun alice_stake_before_upgrade(signer: signer) {
        TokenSwapSyrup::stake<TokenMock::WETH>(&signer, 1u64, CommonHelper::pow_amount<TokenMock::WETH>(1000000));
        let total_stake = TokenSwapSyrup::query_total_stake<TokenMock::WETH>();
        Debug::print(&total_stake);
        assert!(total_stake == CommonHelper::pow_amount<TokenMock::WETH>(1000000), 10010);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::STAR;

    fun admin_turned_on_alloc_mode_and_init_upgrade(signer: signer) {
        // open the upgrade switch
        TokenSwapConfig::set_alloc_mode_upgrade_switch(&signer, true);
        assert!(TokenSwapConfig::get_alloc_mode_upgrade_switch(), 100011);

        // upgrade for global init
        TokenSwapSyrupScript::upgrade_for_init(signer, CommonHelper::pow_amount<STAR::STAR>(10));
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use StarcoinFramework::Debug;

    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapSyrupScript;

    fun upgrade_pool_for_weth(signer: signer) {
        TokenSwapSyrupScript::upgrade_pool_for_token_type<TokenMock::WETH>(signer, 100, false);
        let (alloc_point, _, _, _) = TokenSwapSyrup::query_pool_info_v2<TokenMock::WETH>();
        Debug::print(&alloc_point);
        assert!(alloc_point == 100, 10012);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrup;

    fun add_usdt_pool_v2(signer: signer) {
        TokenSwapSyrup::add_pool_v2<TokenMock::WUSDT>(&signer, 100, 0);
        let (alloc_point, _, _, _) = TokenSwapSyrup::query_pool_info_v2<TokenMock::WUSDT>();
        assert!(alloc_point == 100, 10013);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10002000

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use StarcoinFramework::Token;

    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::STAR;

    fun alice_unstake_no1_after_upgrade(signer: signer) {
        let (unstaked_token, reward_token) = TokenSwapSyrup::unstake<TokenMock::WETH>(&signer, 1);

        let user_addr = Signer::address_of(&signer);
        // Print token amount
        Debug::print(&Token::value<TokenMock::WETH>(&unstaked_token));
        Debug::print(&Token::value<STAR::STAR>(&reward_token));

        // Deposit to account
        Account::deposit<TokenMock::WETH>(user_addr, unstaked_token);
        Account::deposit<STAR::STAR>(user_addr, reward_token);
    }
}
// check: EXECUTED
