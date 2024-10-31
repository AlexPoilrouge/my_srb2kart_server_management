#!/bin/python3

import os
from pathlib import Path

INSTALLED_DIRNAME="installed"
ENABLED_DIRNAME="enabled"

class AddonsHandler:
    def __init__(self, addon_dir):
        self.dir_path= Path(addon_dir)

    def is_addon_enabled(self, addon_filename):
        return (self.dir_path / ENABLED_DIRNAME / addon_filename ).is_symlink()

    def enable_addon(self, addon_filename):
        installed_path = self.dir_path / INSTALLED_DIRNAME / addon_filename
        enabled_path = self.dir_path / ENABLED_DIRNAME / addon_filename

        # Check if the 'installed/addon_filename' file exists
        if installed_path.exists():
            # Ensure 'enabled' directory exists
            os.makedirs(enabled_path.parent, exist_ok=True)
            
            # Create the symlink if it doesn't already exist
            if not enabled_path.exists(follow_symlinks=False):
                os.symlink(installed_path, enabled_path)
                print(f"Created symlink: {enabled_path} -> {installed_path}")
            else:
                print(f"Symlink {enabled_path} already exists.")
        else:
            print(f"File '{installed_path}' does not exist.")

    def disable_addon(self, addon_filename):
        enabled_path = self.dir_path / ENABLED_DIRNAME / addon_filename

        # Check if the symlink exists
        if enabled_path.exists(follow_symlinks=False):
            enabled_path.unlink()  # Remove the symlink
            print(f"Removed symlink: {enabled_path}")
        else:
            print(f"Symlink '{enabled_path}' does not exist.")

