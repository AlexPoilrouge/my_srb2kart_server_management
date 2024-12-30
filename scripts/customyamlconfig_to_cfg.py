#!/bin/python3

import os
import yaml
import argparse
from croniter import croniter
from datetime import datetime

from py_lib.addons import AddonsHandler

addons_handler= None
workDir= None

# Function to read YAML files
def read_yaml(file_path):
    with open(file_path, 'r') as file:
        return yaml.safe_load(file)

# Function to check if current time matches the cron expression
def time_matches_cron(cron_expression):
    current_time = datetime.now().replace(second=0, microsecond=0)
    return croniter.match(cron_expression, current_time)

# Function to validate commands against allowed commands
def validate_commands(config_commands, allowed_commands):
    valid_commands = []
    for command_info in config_commands:
        command = command_info['command']
        if command in allowed_commands:
            arguments = ' '.join(command_info['arguments'])
            valid_commands.append(f"{command} {arguments}")
        else:
            print(f"Skipping invalid command: {command}")
    return valid_commands

def handle_addons(enable_addons, disable_addons, record=True):
    global workDir
    global addons_handler

    l_enabled= []
    for addon in enable_addons:
        if not addons_handler.is_addon_enabled(addon):
            l_enabled.append(addon)
        addons_handler.enable_addon(addon)
    
    l_disabled= []
    for addon in disable_addons:
        if addons_handler.is_addon_enabled(addon):
            l_disabled.append(addon)
        addons_handler.disable_addon(addon)

    if not record:
        return

    addons_enablement_record_file= f"{workDir}/config_addon_record.yaml"
    record= {
        "enabled_to_disable": l_enabled,
        "disabled_to_enable": l_disabled
    }

    with open(addons_enablement_record_file, 'w') as yaml_file:
        yaml.dump(record, yaml_file, default_flow_style=False)

def neutral_config(output_file):
    with open(output_file, 'w') as output:
        output.write("// found nothing\n")
        output.write("wait\n")
    print("No matching triggertime found. Generated neutral config.")

# Main function to process the YAML files and generate the .cfg file
def process_yaml_files():
    global workDir
    config_dir = os.path.join(workDir, 'config.d')
    allowed_commands_file = os.path.join(workDir, 'allowed_commands.yaml')
    output_file = os.path.join(workDir, 'custom_config.cfg')

    try:
        # Step 1: Read allowed commands
        allowed_commands = read_yaml(allowed_commands_file)['allowed_commands']

        # Step 2: Browse config.d/ for YAML files
        yaml_files = [f for f in os.listdir(config_dir) if f.endswith('.yaml')]
    except Exception as e :
        print(f"Configuration generation error - {e}")
        neutral_config(output_file)
        return

    # Step 3: Find the first YAML file with a matching triggertime
    if os.path.isdir(config_dir):
        configs= {}
        for yaml_file in yaml_files:
            try:
                yaml_path = os.path.join(config_dir, yaml_file)
                data = read_yaml(yaml_path)
            except Exception as e:
                print(f"trouble reading '{yaml_path}' - {e}")
                continue

            # If 'triggertime' exists and matches current time
            if 'triggertime' in data:
                triggertime= data['triggertime']
                if triggertime.lower().strip()=="never" or not time_matches_cron(triggertime):
                    continue
                
                try:
                    name = data.get('name', 'Unknown')
                    config_commands = data['configuration']['commands']
                    config_addons = data['configuration']['addons']
                    
                    # Validate commands
                    valid_commands = validate_commands(config_commands, allowed_commands)

                    configs[name]= { "file": yaml_file, "commands": valid_commands, "addons": config_addons }

                    # addons handle, and sort out of disabled those already enabled
                except:
                    print(f"Configuration generation error - {e}")

        if len(configs)<=0:
            print("No configuration to generate…")
            neutral_config(output_file)
            return

        try:
            with open(output_file, 'w') as output:
                for key in configs:
                    config= configs[key]
                    output.write(f"// name:{key}\n")
                    output.write(f"// file:{config['file']}\n")

                    for command in config['commands']:
                        output.write(f"{command}\n")
        except Exception as e:
            print(f"Problem while generating cfg - {e}")
            neutral_config(output_file)
            return

        for key in configs:
            config= configs[key]
            config_addons= config['addons'] if "addons" in config else None

            addons_to_enable= []
            addons_to_disable= []
            if config_addons :
                if 'enable' in config_addons:
                    addons_to_enable+= config_addons['enable']
                if 'disable' in config_addons:
                    addons_to_disable+= config_addons['disable']

                addons_to_enable= list(set(addons_to_enable))
                addons_to_disable= [addon for addon in list(set(addons_to_disable)) if addon not in addons_to_enable]

            try:
                handle_addons(addons_to_enable, addons_to_disable)
            except Exception as e:
                print(f"couldn't properly handle addons for '{key}' config - {e}")

def restore_addons_from_record():
    global workDir
    
    addons_enablement_record_file= f"{workDir}/config_addon_record.yaml"
    if os.path.isfile(addons_enablement_record_file):
        try:
            record= read_yaml(addons_enablement_record_file)
            addons_to_disable= record['enabled_to_disable'] if 'enabled_to_disable' in record else []
            addons_to_enable= record['disabled_to_enable'] if 'disabled_to_enable' in record else []

            handle_addons(addons_to_enable, addons_to_disable, False)
        except Exception as e:
            print(f"Error trying to restore addons for '{addons_enablement_record_file}' - {e}")
    else:
        print('No record of addons files to restore found…')


# Main function to handle argument parsing
def main():
    parser = argparse.ArgumentParser(description="Generate configuration files based on YAML configurations and cron schedules.")
    
    # Argument for the working directory
    parser.add_argument('cmd', type=str, help="script commnand: MAKE_CUSTOM_CFG | RESTORE_ADDONS")
    parser.add_argument('working_directory', type=str, help="Path to the working directory containing 'config.d/' and 'allowed_commands.yaml'.")
    parser.add_argument('addons_directory', type=str, help="Path to the addons directory containing 'enabled' and 'installed' addons subdirs.")

    # Parse the arguments
    args = parser.parse_args()

    global workDir
    workDir= args.working_directory
    global addons_handler
    addons_handler= AddonsHandler(args.addons_directory)

    if args.cmd.upper() in ['RESTORE', 'RESTORE_ADDONS']:
        restore_addons_from_record()
    else:
        # Call the function to process the YAML files
        process_yaml_files()

# Entry point of the script
if __name__ == '__main__':
    main()
