#!/bin/bash
set -ex

# Fix for cross-compilation: replace build prefix with host prefix in torch include paths
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    echo "Patching setup.py for cross-compilation"

    # Create a python script that monkey patches torch.utils.cpp_extension.include_paths
    cat <<EOF > patch_torch_includes.py
import os
import torch.utils.cpp_extension

if "BUILD_PREFIX" in os.environ and "PREFIX" in os.environ:
    build_prefix = os.environ["BUILD_PREFIX"]
    prefix = os.environ["PREFIX"]
    original_include_paths = torch.utils.cpp_extension.include_paths

    def patched_include_paths(cuda=False):
        paths = original_include_paths(cuda)
        # Replace build prefix with host prefix
        return [p.replace(build_prefix, prefix) for p in paths]

    torch.utils.cpp_extension.include_paths = patched_include_paths
EOF

    # Insert the patch import at the beginning of setup.py (after shebang if exists)
    # We assume the first line might be a shebang, so we insert at line 2.
    # We also add the current directory to sys.path to ensure patch_torch_includes can be imported
    # Using a temporary file to avoid issues with sed -i on different platforms
    sed '2i import sys; sys.path.append("."); import patch_torch_includes' setup.py > setup.py.tmp && mv setup.py.tmp setup.py
fi

$PYTHON -m pip install . -vv
