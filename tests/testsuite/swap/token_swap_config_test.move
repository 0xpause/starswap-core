//! account: alice, 10000000000000 0x1::STC::STC
//! account: joe
//! account: admin, 0x4783d08fb16990bd35d83f3e23bf93b8, 10000000000000 0x1::STC::STC
//! account: liquidier, 10000000000000 0x1::STC::STC
//! account: exchanger


//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;

    fun init_token_config(_: signer) {
        let (num, denum) = TokenSwapConfig::get_swap_fee_operation_rate();
        assert(num == 10, 1001);
        assert(denum == 60, 1002);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;

    fun set_token_config(signer: signer) {
        TokenSwapConfig::set_swap_fee_operation_rate(&signer, 20, 100);
        let (num, denum) = TokenSwapConfig::get_swap_fee_operation_rate();
        assert(num == 20, 1003);
        assert(denum == 100, 1003);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;

    fun init_swap_fee_switch_config(_: signer) {
        let auto_convert_switch = TokenSwapConfig::get_fee_auto_convert_switch();
        assert(auto_convert_switch == false, 1006);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;

    fun set_swap_fee_switch_config(signer: signer) {
        TokenSwapConfig::set_fee_auto_convert_switch(&signer, true);
        let auto_convert_switch = TokenSwapConfig::get_fee_auto_convert_switch();
        assert(auto_convert_switch == true, 1007);
    }
}
// check: EXECUTED