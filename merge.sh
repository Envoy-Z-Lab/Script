#!/bin/bash

# Define repo URLs
REPO1_URL="https://github.com/Ratoriku-Studio/device_xiaomi_lavender"
REPO2_URL="https://github.com/Ratoriku-Studio/device_xiaomi_sdm660-common"
MERGED_DIR="merged_android_device"

# Clone the repos
git clone "$REPO1_URL" lavender_temp
git clone "$REPO2_URL" sdm660_common_temp

# Create a new directory for the merged project
mkdir "$MERGED_DIR"

# Copy contents of both repos (excluding .git folders) into merged directory
rsync -av --progress lavender_temp/ "$MERGED_DIR" --exclude .git
rsync -av --progress sdm660_common_temp/ "$MERGED_DIR" --exclude .git

# Optionally, initialize a new Git repo
cd "$MERGED_DIR"
git init
git add .
git commit -m "Initial merge of lavender and sdm660-common repositories"

# Cleanup temp directories
cd ..
rm -rf lavender_temp sdm660_common_temp

echo "Repositories merged into $MERGED_DIR"
