import Darwin

/// Cloud files that are not downloaded ("dataless") must never be pulled down just because we scan them.
enum DatalessPolicy {
    static func disableMaterialization() {
        _ = setiopolicy_np(
            IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES,
            IOPOL_SCOPE_PROCESS,
            IOPOL_MATERIALIZE_DATALESS_FILES_OFF
        )
    }
}
