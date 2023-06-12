# WP Media Cleaner

- This script will remove all non thumbnail media files from the WordPress uploads directory.
- It will also remove all empty directories from the uploads directory.
- It will not remove any files that are not part of the WordPress media library.
- This script is intended to be run from the root of the WordPress installation.
- This script needs wp-cli to be installed and configured.
- This script needs to be run as the same user that owns the WordPress files.

## Requirements

- WP Cli is installed
- WP Config file is present and has correct DB credentials

## Usage

- Download the script
- Make sure that the script is executable
- **Make sure that you make a backup of the WordPress installation before running the script**
- Place the script in the root of the WordPress installation
- Run the script as the same user that owns the WordPress files
- The script will ask for confirmation before deleting any files or directories

## Example

```bash
$ cd /var/www/html
$ chmod +x .wp-media-cleaner.sh
$ chmod 744 ./wp-media-cleaner.sh
$ sudo -u www-data ./wp-media-cleaner.sh
```
