// Copyright 2020 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#include <string>
#include <vector>
#include "common/common_types.h"

namespace Core {

struct SaveStateInfo {
    u32 slot;
    u64 time;
    enum class ValidationStatus {
        OK,
        RevisionDismatch,
    } status;
    std::string build_name;
};

constexpr u32 SaveStateSlotCount = 50; // Maximum count of savestate slots//Manic修改

std::string GetSaveStatePath(u64 program_id, u64 movie_id, u32 slot);
std::vector<SaveStateInfo> ListSaveStates(u64 program_id, u64 movie_id);

} // namespace Core
