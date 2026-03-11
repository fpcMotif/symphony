git clean -fd
patch -p1 < ../test_fix.diff
patch -p1 < ../patch.diff
patch -p1 < ../patch_handle_info_codex.diff
patch -p1 < ../patch_handle_info_down.diff
patch -p1 < ../patch_handle_info_msg.diff
patch -p1 < ../patch_config.diff
patch -p1 < ../fix.diff
