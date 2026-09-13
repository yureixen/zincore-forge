#!/usr/bin/env python3
import re
import sys

NAMEI_PATH = "fs/namei.c"
OPEN_PATH = "fs/open.c"


def detect_vfs_open_call():
    open_c = open(OPEN_PATH).read()
    m = re.search(r"^(?:int|static int)\s+vfs_open\(([^)]*)\)", open_c, re.M)
    if not m:
        print(f"FATAL: could not find vfs_open() definition in {OPEN_PATH}", file=sys.stderr)
        sys.exit(1)
    params = m.group(1)
    has_cred = "cred" in params
    call = "vfs_open(&path, file, current_cred())" if has_cred else "vfs_open(&path, file)"
    print(f"-- detected vfs_open() params: ({params.strip()}) -> using call: {call}")
    return call


def main():
    vfs_open_call = detect_vfs_open_call()
    src = open(NAMEI_PATH).read()

    old_fn = (
        "static int do_o_path(struct nameidata *nd, unsigned flags, struct file *file)\n"
        "{\n"
        "\tstruct path path;\n"
        "\tint error = path_lookupat(nd, flags, &path);\n"
        "\tif (!error) {\n"
        "\t\taudit_inode(nd->name, path.dentry, 0);\n"
        f"\t\terror = {vfs_open_call};\n"
        "\t\tpath_put(&path);\n"
        "\t}\n"
        "\treturn error;\n"
        "}"
    )

    if old_fn not in src:
        print(
            f"FATAL: expected original do_o_path() body not found verbatim in {NAMEI_PATH} "
            "(this tree's do_o_path() differs from what this self-heal expects) — "
            "refusing to guess, leaving the .rej in place for manual review.",
            file=sys.stderr,
        )
        sys.exit(1)

    new_fn = (
        "static int do_o_path(struct nameidata *nd, unsigned flags, struct file *file)\n"
        "{\n"
        "#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT\n"
        "\tint old_dfd = nd->dfd;\n"
        "\tstruct filename *fake_filename = NULL;\n"
        "#endif // #ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT\n"
        "\tstruct path path;\n"
        "\tint error = path_lookupat(nd, flags, &path);\n"
        "\tif (!error) {\n"
        "#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT\n"
        "\t\tif (old_dfd != -1 &&\n"
        "\t\t\tSUSFS_IS_INODE_OPEN_REDIRECT_WITHOUT_UID_CHECK(path.dentry->d_inode))\n"
        "\t\t{\n"
        "\t\t\tfake_filename = susfs_open_redirect_spoof_do_sys_openat(path.dentry->d_inode);\n"
        "\t\t\tif (fake_filename && !IS_ERR(fake_filename)) {\n"
        "\t\t\t\tpath_put(&path);\n"
        "\t\t\t\trestore_nameidata();\n"
        "\t\t\t\tset_nameidata(nd, old_dfd, fake_filename);\n"
        "\t\t\t\terror = path_lookupat(nd, flags, &path);\n"
        "\t\t\t\tif (unlikely(error)) {\n"
        "\t\t\t\t\tputname(fake_filename);\n"
        "\t\t\t\t\treturn error;\n"
        "\t\t\t\t}\n"
        "\t\t\t}\n"
        "\t\t}\n"
        "#endif // #ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT\n"
        "\t\taudit_inode(nd->name, path.dentry, 0);\n"
        f"\t\terror = {vfs_open_call};\n"
        "\t\tpath_put(&path);\n"
        "\t}\n"
        "#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT\n"
        "\tif (fake_filename && !IS_ERR(fake_filename))\n"
        "\t\tputname(fake_filename);\n"
        "#endif // #ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT\n"
        "\treturn error;\n"
        "}"
    )

    src = src.replace(old_fn, new_fn, 1)
    open(NAMEI_PATH, "w").write(src)
    print("-- do_o_path() successfully self-healed with arity-correct vfs_open call")


if __name__ == "__main__":
    main()
