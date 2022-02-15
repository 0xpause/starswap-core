### 设置默认账号和解锁
account default 0x2b3d5bd6d0f8a957e6a4abe986056ba7
account unlock

### 管理员创建swap交易对
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapScripts::register_swap_pair -t 0x1::STC::STC -t 0x4c438026f963f52f01f612d1e8c41bc4::XUSDT::XUSDT  -b
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapScripts::register_swap_pair -t 0x1::STC::STC -t 0xfe125d419811297dfab03c61efec0bc9::FAI::FAI -b
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapScripts::register_swap_pair -t 0x1::STC::STC -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR::STAR -b

### 添加代币对流动性
account execute-function -s 0x4c438026f963f52f01f612d1e8c41bc4 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapScripts::add_liquidity -t 0x1::STC::STC -t 0x4c438026f963f52f01f612d1e8c41bc4::XUSDT::XUSDT --arg 50000000u128 --arg 25000000u128 --arg 5000u128 --arg 5000u128 -b
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapScripts::add_liquidity -t 0x1::STC::STC -t 0xfe125d419811297dfab03c61efec0bc9::FAI::FAI --arg 50000000u128 --arg 25000000u128 --arg 5000u128 --arg 5000u128 -b
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapScripts::add_liquidity -t 0x1::STC::STC -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR::STAR --arg 50000000u128 --arg 25000000u128 --arg 5000u128 --arg 5000u128 -b

### 查询刚刚创建的交易对流动性
dev call --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapRouter::total_liquidity -t 0x1::STC::STC -t 0x4c438026f963f52f01f612d1e8c41bc4::XUSDT::XUSDT
dev call --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapRouter::total_liquidity -t 0x1::STC::STC -t 0xfe125d419811297dfab03c61efec0bc9::FAI::FAI
dev call --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapRouter::total_liquidity -t 0x1::STC::STC -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR::STAR

### Swap Fee admin账号 accept XUSDT
account execute-function -s 0x0a4183ac9335a9f5804014eab01c0abc --function 0x1::Account::accept_token -t 0x4c438026f963f52f01f612d1e8c41bc4::XUSDT::XUSDT  -b
account execute-function -s 0x0a4183ac9335a9f5804014eab01c0abc --function 0x1::Account::accept_token -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR::STAR -b
