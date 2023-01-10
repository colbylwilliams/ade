#!/usr/bin/env python3

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

import argparse
import json
import logging
import os
import shutil
import stat
import subprocess
import sys

from datetime import datetime, timezone
from pathlib import Path

parser = argparse.ArgumentParser(description='Run an action')
parser.add_argument('script', help='The script to run', default=None, nargs='?')
parser.add_argument('--debug', help='Enable debug logging', action='store_true', default=False)

args = parser.parse_args()
cmd_input = args.script
debug_mode = args.debug

timestamp = datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')

ADE_RUNNER = 'ADE_RUNNER'

IN_RUNNER = os.environ.get(ADE_RUNNER)
IN_RUNNER = bool(IN_RUNNER)

AZURE_CLIENT_ID = 'ADE_AZURE_CLIENT_ID'
AZURE_CLIENT_SECRET = 'ADE_AZURE_CLIENT_SECRET'
AZURE_TENANT_ID = 'ADE_AZURE_TENANT_ID'

ADE_ACTION_ID = 'ADE_ACTION_ID'
ADE_ACTION_NAME = 'ADE_ACTION_NAME'
ADE_ACTION_STORAGE = 'ADE_ACTION_STORAGE'
ADE_ENVIRONMENT_SUBSCRIPTION_ID = 'ADE_ENVIRONMENT_SUBSCRIPTION_ID'

ADE_CATALOG = 'ADE_CATALOG'
ADE_CATALOG_ITEM = 'ADE_CATALOG_ITEM'

if IN_RUNNER:
    for var in [ADE_ACTION_ID, ADE_ACTION_NAME, ADE_ACTION_STORAGE, ADE_CATALOG, ADE_CATALOG_ITEM]:
        if not os.environ.get(var):
            raise Exception(f'{var} environment variable not set')

storage = os.environ.get(ADE_ACTION_STORAGE)
action_id = os.environ.get(ADE_ACTION_ID)
action_name = os.environ.get(ADE_ACTION_NAME)
catalog = os.environ.get(ADE_CATALOG)
catalog_item = os.environ.get(ADE_CATALOG_ITEM)
# if not IN_RUNNER:
#     catalog_item = 'Echo'
#     action_name = 'delete'

storage = Path(storage).resolve() / action_id if IN_RUNNER else Path(__file__).resolve().parent.parent.parent / '.local' / 'storage' / 'action'
catalog_item = Path(catalog_item).resolve() if IN_RUNNER else Path(__file__).resolve().parent.parent.parent / 'Environments' / 'Echo'

if IN_RUNNER:
    storage.mkdir(parents=True, exist_ok=True)


def get_logger(name):
    '''Get the logger for the extension'''
    _logger = logging.getLogger(name)
    _logger.setLevel(logging.DEBUG if debug_mode else logging.INFO)

    # this must only happen in the builder, otherwise
    # the log file could be created on users machines
    # if IN_RUNNER and storage.is_dir():
    if storage.is_dir():
        log_file = storage / 'runner.log'
        formatter = logging.Formatter('{asctime} [{name:^10}] {levelname:<8}: {message}',
                                      datefmt='%m/%d/%Y %I:%M:%S %p', style='{',)
        fh = logging.FileHandler(log_file)
        fh.setLevel(level=_logger.level)
        fh.setFormatter(formatter)
        _logger.addHandler(fh)

    return _logger


log = get_logger(__name__)

log.info('##################################')
log.info('Azure Depoyment Environment Runner')
log.info('##################################')
log.info('')
log.info(f'IN_RUNNER: {IN_RUNNER}')
log.info('')
log.info(f'Running action: {action_name}')
log.info('')
log.info('Environment variables:')
log.info('======================')
for key, value in os.environ.items():
    log.info(f'{key}: {value}')


def error_exit(message):
    log.error(message)
    sys.exit(message)


if not catalog_item.is_dir():
    error_exit(f'Catalog item {catalog_item} not found')


def az_cli(command, log_command=True):
    '''Runs an azure cli command and returns the json response'''
    if isinstance(command, list):
        args = command
    elif isinstance(command, str):
        args = command.split()
    else:
        error_exit(f'az command must be a string or list, not {type(command)}')

    az = shutil.which('az')

    if args[0] == 'az':
        args.pop(0)
    if args[0] != az:
        args = [az] + args

    try:
        log.info('')
        cmd_string = f': {" ".join(args)}' if log_command else ''
        log.info(f'Running az cli command{cmd_string}')
        proc = subprocess.run(args, capture_output=True, check=True, text=True)
        if proc.returncode == 0 and not proc.stdout:
            return None
        for line in proc.stdout.splitlines():
            log.info(line)
        resource = json.loads(proc.stdout)
        return resource

    except subprocess.CalledProcessError as e:
        if e.stderr and 'Code: ResourceNotFound' in e.stderr:
            return None
        error_exit(e.stderr if e.stderr else 'azure cli command failed')
    except json.decoder.JSONDecodeError:
        error_exit('{}: {}'.format('Could not decode response json', proc.stderr if proc.stderr else proc.stdout if proc.stdout else proc))


def az_login():
    log.info('')
    az_client_id = os.environ.get(AZURE_CLIENT_ID)
    az_client_secret = os.environ.get(AZURE_CLIENT_SECRET)
    az_tenant_id = os.environ.get(AZURE_TENANT_ID)

    if az_client_id and az_client_secret and az_tenant_id:
        log.info(f'Found credentials for Azure Service Principal')
        log.info(f'Logging in with Service Principal')
        az_cli(f'az login --service-principal -u {az_client_id} -p {az_client_secret} -t {az_tenant_id} --allow-no-subscriptions', log_command=False)
    else:
        log.info(f'No credentials for Azure Service Principal')
        log.info(f'Logging in to Azure with managed identity')
        az_cli('az login --identity --allow-no-subscriptions')

    subscription_id = os.environ.get(ADE_ENVIRONMENT_SUBSCRIPTION_ID)
    if subscription_id:
        log.info(f'Setting subscription to {subscription_id}')
        az_cli(f'az account set --subscription {subscription_id}')


def run_script(script: Path):
    log.info('')
    log.info(f'Executing {script}')
    if not script.is_file():
        error_exit(f'{script} not found')

    if script.suffix == '.sh':
        sh = shutil.which('sh')
        args = [sh, str(script)]
    elif script.suffix == '.py':
        p3 = shutil.which('python3')
        args = [p3, str(script)]
    else:
        error_exit(f'Unsupported script type: {script.suffix}')

    if not os.access(script, os.X_OK):
        log.info(f'{script} is not executable, setting executable bit')
        script.chmod(script.stat().st_mode | stat.S_IEXEC)

    try:
        log.info(' '.join(args))
        proc = subprocess.run(args, capture_output=True, check=True, text=True)
        if proc.stdout:
            for line in proc.stdout.splitlines():
                log.info(line)
        if proc.stderr:
            error_exit(f'\n\n{proc.stderr}')
    except subprocess.CalledProcessError as e:
        error_exit(f'Error executing {script} {e.stderr}')


def get_action_script(dirpath: Path, action: str) -> Path:
    log.info('')
    log.info(f'Checking for action scripts in {dirpath}...')

    sh_path = dirpath / f'{action}.sh'
    py_path = dirpath / f'{action}.py'

    sh_isfile = sh_path.is_file()
    py_isfile = py_path.is_file()

    if sh_isfile or py_isfile:
        if sh_isfile and py_isfile:
            error_exit(f'Found both {action}.sh and {action}.py in {dirpath}. Only one script file allowed.')

        action_script = sh_path if sh_isfile else py_path
        log.info(f'Found {action} script: {action_script}')
        return action_script
    log.info(f'No {action} script found')
    return None


actions_d = Path('/actions.d') if IN_RUNNER else Path(__file__).resolve().parent / 'actions.d'
entrypoint_d = Path('/entrypoint.d') if IN_RUNNER else Path(__file__).resolve().parent / 'entrypoint.d'


# if this image is used as a base for a custom image, the user can
# add files to the /entrypoint.d directory to be executed at startup
log.info('')
log.info(f'Checking for scripts in {entrypoint_d}...')
if entrypoint_d.is_dir():
    entrypoint_scripts = sorted(list(entrypoint_d.glob('*.sh')) + list(entrypoint_d.glob('*.py')))
    if entrypoint_scripts:
        log.info(f'Found {len(entrypoint_scripts)} scripts')
        for script in entrypoint_scripts:
            log.info(f' {script}')
        for script in entrypoint_scripts:
            run_script(script)

if IN_RUNNER:
    az_login()

sub = az_cli('az account show')
log.info('')
log.info(f'Current subscription: {sub["name"]} ({sub["id"]})')


# the script to execute is defined by the following options
# (the first option matching an executable script file wins)
#
# Option 1: a script path is provided as docker CMD command
#
# Option 2: a script file following the pattern [ACTION_NAME].sh exists in the
#           catalog item directory
#
# Option 3: a script file following the pattern [ACTION_NAME].sh exists in the
#           /actions.d directory (actions script directory)


script = None

if cmd_input:
    log.info(f'CMD input found: {cmd_input}')
    cmd_input = Path(cmd_input).resolve()
    if not cmd_input.is_file():
        log.info(f'CMD input script is not a file, ignoring: ({cmd_input})')
        # error_exit(f'Invalid script path provided in CMD input: {script}')
    elif cmd_input.suffix != '.sh' and cmd_input.suffix != '.py':
        error_exit(f'Invalid script type provided in CMD input: {cmd_input} (only .sh and .py scripts are supported)')
    else:
        script = cmd_input

if script is None:
    script = get_action_script(catalog_item, action_name)

if script is None:
    script = get_action_script(actions_d, action_name)

if script is not None:
    run_script(script)
    log.info('')
    log.info('Done.')
    sys.exit(0)
else:
    error_exit(f'No script found for action: {action_name}')
