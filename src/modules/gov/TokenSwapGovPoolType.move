// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
address 0x2b3d5bd6d0f8a957e6a4abe986056ba7 {
module TokenSwapGovPoolType {
    struct PoolTypeInitialLiquidity has key, store {}

    struct PoolTypeFarmPool has key, store {}

    struct PoolTypeSyrup has key, store {}

    struct PoolTypeTeam has key, store {}

    struct PoolTypeCommunity has key, store {}

    struct PoolTypeDaoTreasury has key, store {}
}
}