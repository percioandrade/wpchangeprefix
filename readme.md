# WordPress Database Prefix Change Script 🔄

# About 📝
A shell script to safely change WordPress database table prefixes with backup functionality and version control.

- Author 👨‍💻
- Percio Andrade
- Email: percio@zendev.com.br
- Website: Zendev : https://zendev.com.br

## Features ✨
- Automatic prefix detection from existing tables
- Database credentials extraction from wp-config.php
- Optional database backup before changes
- Safe table renaming with confirmation
- Updates relevant wp_options and wp_usermeta entries
- Interactive prefix input with backspace support
- Input validation and error handling

## Requirements 📋
- Bash shell environment
- MySQL/MariaDB access
- WordPress installation with wp-config.php
- Appropriate database permissions

## Usage 🚀
```bash
./change_prefix.sh [-s|--skip] [-n|--noversion]
```

# Options
- `-n`, `--noversion`: Skip version check
- `-s`, `--skip`: Skip database backup creation
- `-h`, `--help`: Display help message

# How It Works 🔧
- Extracts database credentials from wp-config.php
- Detects current table prefix automatically
- Creates database backup (optional)
- Prompts for new prefix input
- Renames all tables with new prefix
- Updates metadata references in options and usermeta tables

# Safety Features 🛡️
- Validates database connection before changes
- Creates automatic backups by default
- Confirms actions before execution
- Validates user input
- Handles errors gracefully

# Notes 📌
- Ensure you have the necessary permissions to run the script as root.
- Make sure all required commands are installed on your system.
- Always backup your database before running
- Ensure proper database permissions
- Run from WordPress root directory

# License 📄
This project is licensed under the GNU General Public License v2.0