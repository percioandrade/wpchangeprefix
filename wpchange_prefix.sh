#!/bin/bash
##################################################################
# WordPress Database Prefix Change Script
#
# A shell script to safely change the WordPress database table prefix.
# Provides options for version checking and database backup skipping.
#
# Features:
# - Automatic prefix detection from existing tables
# - Database credentials extraction from wp-config.php
# - Optional database backup before changes
# - Safe table renaming with confirmation
# - Updates relevant wp_options and wp_usermeta entries
#
# Usage: ./change_prefix.sh [-s|--skip] [-n|--noversion]
#
# Options:
#   -n, --noversion   Skip version check
#   -s, --skip        Skip database backup creation
#   -h, --help        Display help message
#
# Author: Percio Andrade
# Email: percio@zendev.com.br
# Version: 1.1
##################################################################

function display_help() {
    cat <<-EOF
    Usage: $0 [-s|--skip] [-n|--noversion]

    Options:
            -n, --noversion   Skip version check      
            -s, --skip        Skip database dump creation
EOF
}

# Check for help option
if [[ $1 == "-h" ]] || [[ $1 == "--help" ]]; then
    display_help
    exit
fi

V='1.1'
URL='https://raw.githubusercontent.com/percioandrade/wpchangeprefix/refs/heads/main/wpchange_prefix.sh'

# Skip version check
if [[ " $* " == *" -n "* || " $* " == *" --noversion "* ]]; then
    echo '[!] We will not check this script version'
else
    # Check script version
    V_URL=$(GET ${URL}|grep -m1 "V="|cut -d "'" -f2)
    if [[ ${V} != ${V_URL} ]];then
        echo '[!] A new update for this script was released. Version '${V_URL}''
        echo '[!] Please update on update on '${URL}''
    fi
fi

echo '[!] Starting'

# Check if the wp-config.php file exists
FILE="wp-config.php"

if [[ -f "${FILE}" ]]; then
    echo '[+] File wp-config.php was found'
else
    echo '[!] File wp-config.php not found, exiting...'
    exit 1
fi

# Function to extract values from the config file
get_db_value() {
    local key="$1"
    grep -i "$key" "${FILE}" | grep -v '#' | awk -F "[=']" '{print $4}'
}

# Extract database credentials
DATABASE=$(get_db_value "DB_NAME")
DB_USER=$(get_db_value "DB_USER")
DB_PASS=$(get_db_value "DB_PASSWORD")
DB_HOST=$(get_db_value "DB_HOST")

# Check if any values are empty
if [[ -z "${DATABASE}" || -z "${DB_USER}" || -z "${DB_PASS}" || -z "${DB_HOST}" ]]; then
    echo '[!] - Empty values, exiting...'
    exit 1
fi

echo '[+] Database values founded'

echo $'
------------------------
| Database: '${DATABASE}'
| User: '${DB_USER}'
| Password: '${DB_PASS}'
| Host: '${DB_HOST}'
------------------------
'

echo '[!] Checking the current prefix'
echo '[!] Trying to establish a connection, please wait....'

# Connecting to MySQL to retrieve the table prefix
PREFIX=$(mysql -N -s -u "${DB_USER}" -p"${DB_PASS}" -h "${DB_HOST}" -e "SELECT table_name FROM information_schema.tables WHERE table_schema = '${DATABASE}' AND table_name LIKE '%options' LIMIT 1;")
MYSQL_EXIT_CODE=$?
PREFIX="${PREFIX%"_options"}"_

if [[ $MYSQL_EXIT_CODE -eq 0 ]]; then
    if [[ -z "${PREFIX}" ]]; then
        echo '[!] Unable to determine the database '${DATABASE}' prefix'
    else
        echo '[+] The actual database '${DATABASE}' prefix is: '${PREFIX}''
    fi
else
    echo '[!] Connection to MySQL failed. Please check your database credentials'
    exit 1
fi

# Ask if the user wants to skip the database dump
if [[ " $* " == *" -s "* || " $* " == *" --skip "* ]]; then
    echo '[!] Skip database used, we will not generate a backup'
else
    # Generate a database dump using the determined prefix
    DUMP_FILE="${PREFIX}db_backup_$(date +%Y%m%d%H%M%S).sql"
    mysqldump -u "${DB_USER}" -p"${DB_PASS}" -h "${DB_HOST}" "${DATABASE}" > "${DUMP_FILE}"
    echo '[!] Dumping database, please wait...'
    echo '[+] Database dump created on: '$(pwd)/${DUMP_FILE}''
fi

echo $'[!] Please insert the new prefix. Example: dev'
echo $'[!] Dont insert long value, the recommended is 2 a 4 characters\n'

NEW_PREFIX=""
while IFS= read -r -s -n 1 char; do
    if [[ $char == $'\0' ]]; then
        break
    fi

    # Check if the character is a letter, a digit, or backspace
    if [[ $char =~ [[:alnum:]] || $char == $'\177' ]]; then
        if [[ $char == $'\177' ]]; then  # Check for backspace (ASCII value 127)
            if [[ -n $NEW_PREFIX ]]; then
                echo -en "\b \b"  # Erase last character
                NEW_PREFIX=${NEW_PREFIX%?}  # Remove last character from the variable
            fi
        else
            echo -n "$char"
            NEW_PREFIX+="$char"
        fi
    fi
done

NEW_PREFIX="${NEW_PREFIX}_"

echo $'\n
[!] Attention this script will change the '${DATABASE}' actual prefix '${PREFIX}' to new prefix '${NEW_PREFIX}'
'
read -p 'Do you want to continue? (y/n): ' RESPONSE

# Convert the response to lowercase for comparison
RESPONSE=$(echo "${RESPONSE}" | tr '[:upper:]' '[:lower:]')

# Loop until a valid response is given
while [[ "${RESPONSE}" != "y" && "${RESPONSE}" != "n" ]]; do
    echo 'Invalid response. Please enter 'y' or 'n'.'
    read -p 'Do you want to continue? (y/n): ' RESPONSE
    RESPONSE=$(echo "${RESPONSE}" | tr '[:upper:]' '[:lower:]')
done

if [[ "${RESPONSE}" == "y" ]]; then

    echo $'\n[!] Continuing...'

    # Change the database prefix
    if [[ -n "$NEW_PREFIX" ]]; then
        echo $'[+] Changing database prefix...\n'
        
        # Rename all tables with the old prefix to the new prefix
        for table in $(mysql -u "${DB_USER}" -p"${DB_PASS}" -h "${DB_HOST}" "${DATABASE}" -N -B -e "SHOW TABLES LIKE '${PREFIX}%';"); do
            new_table="${NEW_PREFIX}${table#${PREFIX}}"
            mysql -u "${DB_USER}" -p"${DB_PASS}" -h "${DB_HOST}" "${DATABASE}" -e "RENAME TABLE ${DATABASE}.${table} TO ${DATABASE}.${new_table};"
        done

        echo '[+] Usermeta and options tables updating...'

		# Update usermeta and options tables
        mysql -u "${DB_USER}" -p"${DB_PASS}" -h "${DB_HOST}" "${DATABASE}" -e "
        UPDATE \`${NEW_PREFIX}options\` SET option_name = '${NEW_PREFIX}user_roles' WHERE option_name = '${PREFIX}user_roles';
        UPDATE \`${NEW_PREFIX}usermeta\` SET meta_key  = '${NEW_PREFIX}capabilities' WHERE meta_key = '${PREFIX}capabilities';
        UPDATE \`${NEW_PREFIX}usermeta\` SET meta_key  = '${NEW_PREFIX}user_level' WHERE meta_key = '${PREFIX}user_level';
        UPDATE \`${NEW_PREFIX}usermeta\` SET meta_key  = '${NEW_PREFIX}autosave_draft_ids' WHERE meta_key = '${PREFIX}autosave_draft_ids';"

        echo $'[+] Displaying values from database\n'

        echo $'Database '${DATABASE}' new prefix is '${NEW_PREFIX}''

        echo $'\n[+] All values was updated\n'

    else
        echo $'\n[!] New prefix is empty. No changes made\n'
    fi

else
    echo $'\nExiting...\n'
    exit 1
fi