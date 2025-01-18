#!/bin/python3

import os
from pathlib import Path
import re
from typing import List

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

    def get_installed_addons_filenames_from_regex(self, rgx : str) -> List[str]:
        installed_dirpath = self.dir_path / INSTALLED_DIRNAME
        if not installed_dirpath.exists():
            print(f"No addons 'installed' directory.")
            return []

        try:
            pattern= re.compile(rgx)
            addons= []

            for addon_filename in os.listdir(installed_dirpath):
                print(f"-- --> checking file '{addon_filename}' against rgx '{rgx}' [{pattern}]")
                addon_full_path = os.path.join(installed_dirpath, addon_filename)
                if os.path.isfile(addon_full_path) and pattern.search(addon_full_path):
                    addons.append(addon_filename)
        except Exception as e:
            print(f"Error reading files matchin '{rgx}' in '{installed_dirpath}'. - {e}")
        finally:
            return addons

    def get_installed_addons_filenames_from_ptr_list(self, ptr_list) -> List[str]:
        addons= []
        for addon_ptr in ptr_list:
            if "text" in addon_ptr:
                addons.append(addon_ptr["text"])
            elif "regex" in addon_ptr:
                rgx_str= addon_ptr["regex"]
                matched_addons= self.get_installed_addons_filenames_from_regex(rgx_str)
                print(f"=> matched addons from rgx '{rgx_str}': {matched_addons}")
                addons+= matched_addons
        return addons
                




