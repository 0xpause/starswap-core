### bridge合约admin账号
account import -i 0xf4611222ffb7a0d348596132b94ac63f61e78bea4da87d3d9f9009b2abb4ce82
account default 0x4c438026f963f52f01f612d1e8c41bc4
account unlock 0x4c438026f963f52f01f612d1e8c41bc4
dev get-coin 0x4c438026f963f52f01f612d1e8c41bc4

### Swap Fee admin账号
account import -i 0x1f5bfa4af32fe7c0604efba5146e3341153ff8245cc39a1e4000d09727a58f03
account default  0x0a4183ac9335a9f5804014eab01c0abc
account unlock 0x0a4183ac9335a9f5804014eab01c0abc
dev get-coin 0x0a4183ac9335a9f5804014eab01c0abc

### Swap合约admin账号，0x7d50cc0b71d372299d5a3f8aeabc9aa6b911628b6865d9ed78985124633eea37 为老账户
account import -i 0xb9ac5b4924d01efa8c3e465b5df31416f76907c6deffd8956a5ef508bb87af02
account default 0x2b3d5bd6d0f8a957e6a4abe986056ba7
account unlock 0x2b3d5bd6d0f8a957e6a4abe986056ba7
dev get-coin 0x2b3d5bd6d0f8a957e6a4abe986056ba7

### 部署XUSDT
dev deploy storage/0x4c438026f963f52f01f612d1e8c41bc4/modules/XUSDT.mv -s 0x4c438026f963f52f01f612d1e8c41bc4  -b
dev deploy storage/0x4c438026f963f52f01f612d1e8c41bc4/modules/XUSDTScripts.mv -s 0x4c438026f963f52f01f612d1e8c41bc4 -b

### XUSDT注册/发币
account execute-function  --function 0x4c438026f963f52f01f612d1e8c41bc4::XUSDTScripts::init -s 0x4c438026f963f52f01f612d1e8c41bc4 -b
account execute-function  --function 0x4c438026f963f52f01f612d1e8c41bc4::XUSDTScripts::mint --arg 20088888000000000u128 -s 0x4c438026f963f52f01f612d1e8c41bc4 -b

dev package -n proxima -o package storage/0x2b3d5bd6d0f8a957e6a4abe986056ba7/
dev deploy -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 package/proxima.blob -b

# 提交带时间设置的升级配置（10s）
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::UpgradeScripts::update_module_upgrade_strategy_with_min_time --arg 1u8 --arg 10000u64 -b

### Swap Fee admin账号 accept XUSDT
account execute-function --function 0x1::Account::accept_token -t 0x4c438026f963f52f01f612d1e8c41bc4::XUSDT::XUSDT -s 0x0a4183ac9335a9f5804014eab01c0abc -b

### 治理币创世初始化
account execute-function  --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapGovScript::genesis_initialize -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 -b

### 设置swap operation fee rate
account execute-function  --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapScripts::set_swap_fee_operation_rate --arg 10u64 --arg 60u64  -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 -b

### 提取STAR
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapGovScript::dispatch -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapGovPoolType::PoolTypeDaoCrosshain --arg  0x2b3d5bd6d0f8a957e6a4abe986056ba7  --arg 210000000000000u128 -b
