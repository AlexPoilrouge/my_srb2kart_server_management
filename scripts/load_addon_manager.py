#!/bin/python3

import os
import sys
import re
import yaml

def load_yaml(yaml_path):
    with open(yaml_path, 'r') as file:
        return yaml.safe_load(file)

def get_files(directory):
    return sorted(os.listdir(directory))

def apply_position_rule(files, filename, position):
    if filename in files:
        files.remove(filename)
        if position == 'first':
            files.insert(0, filename)
        elif position == 'last':
            files.append(filename)
    return files

def apply_order_rule(files, filename, target, order):
    if filename in files and target in files:
        files.remove(filename)
        target_index = files.index(target)
        if order == 'before':
            files.insert(target_index, filename)
        elif order == 'after':
            files.insert(target_index + 1, filename)
    return files

def find_matching_files(files, pattern):
    return [file for file in files if re.fullmatch(pattern, file)]

def apply_rules(files, rules):
    for rule in rules:
        filename_rule = rule.get('filename', {})
        rules_to_apply = rule.get('rules', [])
        
        # Determine the target file(s) to apply the rules
        if 'text' in filename_rule:
            targets = [filename_rule['text']]
        elif 'regex' in filename_rule:
            targets = find_matching_files(files, filename_rule['regex'])
        else:
            continue
        
        for target in targets:
            for rule in rules_to_apply:
                if 'position' in rule:
                    files = apply_position_rule(files, target, rule['position'])
                elif 'before' in rule:
                    before_rule = rule['before']
                    if 'text' in before_rule:
                        files = apply_order_rule(files, target, before_rule['text'], 'before')
                    elif 'regex' in before_rule:
                        before_targets = find_matching_files(files, before_rule['regex'])
                        for before_target in before_targets:
                            files = apply_order_rule(files, target, before_target, 'before')
                elif 'after' in rule:
                    after_rule = rule['after']
                    if 'text' in after_rule:
                        files = apply_order_rule(files, target, after_rule['text'], 'after')
                    elif 'regex' in after_rule:
                        after_targets = find_matching_files(files, after_rule['regex'])
                        for after_target in after_targets:
                            files = apply_order_rule(files, target, after_target, 'after')
    
    return files

def main():
    # Determine the directory where the script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Paths to the directory and YAML file based on the script's location
    directory = os.path.join(script_dir, 'addons/enabled')
    yaml_path = os.path.join(script_dir, 'addons/addons_order.yaml')
    
    # Ensure the directory and YAML file exist
    if not os.path.exists(directory):
        print(f"Error: Directory '{directory}' does not exist.", file=sys.stderr)
        return
    
    # Load files from the directory
    files = get_files(directory)    
    if not os.path.exists(yaml_path):
        print(f"Error: YAML file '{yaml_path}' does not exist.", file=sys.stderr)
        for file in files:
            print(file)
        return
    
    try:
        # Load rules from the YAML file
        yaml_data = load_yaml(yaml_path)
    except yaml.YAMLError as e:
        print(f"Error: Failed to parse YAML file '{yaml_path}'.", file=sys.stderr)
        print(f"Details: {e}", file=sys.stderr)
        for file in files:
            print(file)
        return
    
    # Retrieve rules, defaulting to an empty list if not present
    rules = yaml_data.get('rules', [])
    
    # Apply the ordering rules
    ordered_files = apply_rules(files, rules)
    
    # Output the final ordered list of files
    for file in ordered_files:
        # print(os.path.join(directory,file))
        print(file)

if __name__ == "__main__":
    main()
