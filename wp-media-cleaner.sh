#!/bin/bash

# This script will remove all non thumbnail media files from the WordPress uploads directory.
# It will also remove all empty directories from the uploads directory.
# It will not remove any files that are not part of the WordPress media library.
# This script is intended to be run from the root of the WordPress installation.
# This script needs wp-cli to be installed and configured.
# This script needs to be run as the same user that owns the WordPress files.

# Welcome the user and ask if wp-cli is installed and configured.
echo "Welcome to the WordPress Media Cleanup script."
echo "This script will remove all non thumbnail media files from the WordPress uploads directory."

# Write a function to exit program with a closing message if called. The function takes an argument which is the message to be displayed.
function exit_program {
    echo ""
    echo ""
    [ -z "$1" ] && echo "Exiting WP Media Cleaner." || echo "$1"
    echo ""
    echo ""
    exit 1
}

# Set variable to current directory
CURRENT_DIR=$(pwd)
# Set Variable to uploads directory
UPLOADS_DIR=$(wp eval 'echo wp_upload_dir()["basedir"];')
# Batch size for deleting attachments
BATCH_SIZE=20

# Ask the user if they want to continue.
echo ""
read -p "Do you want to continue? (y/n) " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit_program
fi

# Check if the user is in the correct directory.
if ! [ -f "wp-config.php" ]; then
    exit_program "Error: wp-config.php not found. Please run this script from the root of the WordPress installation."
fi

# Check if wp-cli is installed.
if ! [ -x "$(command -v wp)" ]; then
    exit_program "Error: wp-cli is not installed."
fi

# Check if uploads directory exists.
if ! [ -d "$UPLOADS_DIR" ]; then
    exit_program "Error: uploads directory not found."
fi

# Ask the user if they have made a backup of the database as well as the files.
echo ""
read -p "Have you made a backup of the database as well as the files? (y/n) " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit_program "Please make a backup of the database as well as the files and then run this script again."
fi

# Ask the user for start to search for media files in posts & pages (any files before this date will not be included in the search & delete).
START_DATE=""
echo ""
read -p "Specify a start date to search for media files in posts & pages (any files before this date will not be included in the search & delete). Leave blank to search all posts & pages. (YYYY-MM-DD) " START_DATE
# While loop to check if the date is correct.
while [[ ! $START_DATE =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; do
    if [[ $START_DATE == "" ]]; then
        break
    fi
    echo ""
    read -p "Please enter a valid date (YYYY-MM-DD) " START_DATE
done

# Ask the user if they want to update the batch count which defaults to 20
echo ""
read -p "Do you want to update the batch count (Number of files deleted at one time)? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    read -p "Enter the number of attachments to delete at a time (default is 20)" BATCH_SIZE
    while ! [[ "$BATCH_SIZE" =~ ^[0-9]+$ ]]; do
        echo ""
        read -p "Please enter a valid number " BATCH_SIZE
    done
fi

# Identify the wordpress database prefix
WP_PREFIX=$(wp db prefix)
echo ""
echo "WORDPRES PREFIX: $WP_PREFIX"
echo ""

# Identify site url
SITE_URL=$(wp option get siteurl)
echo ""
echo "SITE URL: $SITE_URL"
echo ""

echo ""
echo "Searching database for attachments..."
echo ""

# Get all attachments that are thumbnails and satify the begin date if specificed.
if [[ $START_DATE == "" ]]; then
    ALL_ATTACHMENTS=$(wp db query "SELECT ID FROM ${WP_PREFIX}posts WHERE post_type = 'attachment'" | awk '/^[0-9]+$/ {printf "%s ", $1}')
    else
    ALL_ATTACHMENTS=$(wp db query "SELECT ID FROM ${WP_PREFIX}posts WHERE post_type = 'attachment' AND post_date > '$START_DATE'" | awk '/^[0-9]+$/ {printf "%s ", $1}')
fi
ALL_ATTACHMENTS_ARRAY=($ALL_ATTACHMENTS) 
ALL_ATTACHMENTS_COUNT=${#ALL_ATTACHMENTS_ARRAY[@]}

if [[ $ALL_ATTACHMENTS_COUNT == 0 ]]; then
    exit_program "No attachments found after the specified start date of $START_DATE."
fi

ALL_THUMBNAIL_ATTACHMENTS=$(wp db query "SELECT meta_value FROM ${WP_PREFIX}postmeta WHERE meta_key = '_thumbnail_id'" | awk '/^[0-9]+$/ {printf "%s ", $1}')
ALL_THUMBNAIL_ATTACHMENTS_ARRAY=($ALL_THUMBNAIL_ATTACHMENTS)
ALL_THUMBNAIL_ATTACHMENTS_COUNT=${#ALL_THUMBNAIL_ATTACHMENTS_ARRAY[@]}
TO_BE_DELETED_ATTACHMENTS=""

# Loop through all attachments and create a list of attachments to be deleted (the ones that don't appear in ALL_THUMBNAIL_ATTACHMENTS).
for ATTACHMENT_ID in $ALL_ATTACHMENTS; do
    if [[ ! " ${ALL_THUMBNAIL_ATTACHMENTS_ARRAY[@]} " =~ " ${ATTACHMENT_ID} " ]]; then
        TO_BE_DELETED_ATTACHMENTS+="$ATTACHMENT_ID "
    fi
done

TO_BE_DELETED_ATTACHMENTS_ARRAY=($TO_BE_DELETED_ATTACHMENTS)
TO_BE_DELETED_ATTACHMENTS_COUNT=${#TO_BE_DELETED_ATTACHMENTS_ARRAY[@]}

# Ask the user if they want to proceed and give the number of total and to be deleted attachments.
echo ""
echo "Total attachments: $ALL_ATTACHMENTS_COUNT"
echo "Total thumbnail attachments: $ALL_THUMBNAIL_ATTACHMENTS_COUNT"
echo "Total attachments to be deleted (Non thumbnails): $TO_BE_DELETED_ATTACHMENTS_COUNT"
echo ""

read -p "Are you sure, you want to proceed? This will delete all non thumbnail images from the system (y/n) " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit_program
fi

echo "" 
echo "Deleting attachments..."
echo ""

# Loop through all attachments to be deleted and delete them in batches of w0.
for (( i=0; i<$TO_BE_DELETED_ATTACHMENTS_COUNT; i+=$BATCH_SIZE )); do
    # Get the next attachments to be deleted.
    TO_BE_DELETED_ATTACHMENTS_BATCH=$(echo ${TO_BE_DELETED_ATTACHMENTS_ARRAY[@]:$i:$BATCH_SIZE}) 
    # Delete the attachments.
    wp post delete --force $TO_BE_DELETED_ATTACHMENTS_BATCH
  
    # Echo the progress to the user.
    TO_BE_DELETED_ATTACHMENTS_BATCH_ARRAY=($TO_BE_DELETED_ATTACHMENTS_BATCH)
    TO_BE_DELETED_ATTACHMENTS_BATCH_COUNT=${#TO_BE_DELETED_ATTACHMENTS_BATCH_ARRAY[@]}
    echo ""
    echo "Progress: $((i + TO_BE_DELETED_ATTACHMENTS_BATCH_COUNT)) / $TO_BE_DELETED_ATTACHMENTS_COUNT attachments deleted."
    echo ""
done 

echo ""
echo "Finished - Deleted $TO_BE_DELETED_ATTACHMENTS_COUNT attachments."
echo ""

# Delete all empty directories in the uploads directory.
echo ""
echo "Deleting empty directories..."
echo ""

find $UPLOADS_DIR -type d -empty -delete

echo ""
echo "Finished - Deleted empty directories."
echo ""

echo ""
echo "It is best to remove this script once used."
echo ""

# Ask the user if they want to delete this script.
read -p "Do you want to delete this script? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm $CURRENT_DIR/wp-media-cleaner.sh
    echo ""
    echo "Script deleted. - Goodbye!"
    echo ""
fi