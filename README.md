# Encrypted LUKS Workspace

## Usage

```bash
WELCOME TO ELWORK (encrypted luks workspace)!
Usage: ./elwork.sh [OPTIONS]
       --action      Perform an action on the workspace name. Valid options include: list, new, rotate, unschedule, mount, unmount, passwd, remove, archive, replace, change (default = 'list')
       --encrypt     Flag to enable luks encryption (default = 'false')
       --log         Path to log file (default = './elwork.sh.2024-07-06.log')
       --name        Name of the workspace to manage. (default = 'andrei_workspace_2024-07')
       --parent      Path to store workspaces and index of elwork. (default = '/home/andrei/.elwork')
       --password    Password to encrypt/decrypt the luks workspace (default = 'T3stP@ssw0rd!')
       --size        Size of the workspace. Valid options include: cd (650 MB), dvd (4500 MB), dvddl (8500 MB), bd (24000 MB), bddl (48000 MB) or any #[M|G|T]B. (default = '650')
       --sudo        Flag to enable sudo before running commands (default = 'false')
       --type        Type of filesystem to use. Valid options include: xfs, ext4 (default = 'xfs')

```
