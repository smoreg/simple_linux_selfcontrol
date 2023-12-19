#!/bin/bash

# Check if the script is being run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root using sudo."
  exit 1
fi

# Set default block duration in minutes (e.g., 60 minutes = 1 hour)
block_duration_minutes=60

# Check if there are arguments passed for websites to block
if [ $# -lt 2 ]; then
  echo "Usage: $0 <block_duration_in_minutes> <website1> <website2> ..."
  exit 1
fi

# Parse the block duration from command-line argument
block_duration_minutes="$1"
shift

# Convert block_duration_minutes to seconds
block_duration_seconds=$((block_duration_minutes * 60))

# Check if the duration is a valid number
if ! [[ "$block_duration_seconds" =~ ^[0-9]+$ ]]; then
  echo "Invalid block duration: $block_duration_minutes minutes."
  exit 1
fi

# Define the list of websites to block from the remaining command-line arguments
websites_to_block=("$@")

# Function to block websites
block_websites() {
  for website in "${websites_to_block[@]}"; do
    echo "127.0.0.1 $website" >> /etc/hosts
    echo "127.0.0.1 www.$website" >> /etc/hosts
  done

  # Flush DNS cache (Linux distribution dependent)
  if command -v systemctl >/dev/null && systemctl is-active --quiet NetworkManager; then
    systemctl restart NetworkManager
  elif command -v service >/dev/null && service networking restart; then
    service networking restart
  elif command -v /etc/init.d/networking restart; then
    /etc/init.d/networking restart
  else
    echo "Failed to flush DNS cache. You may need to do it manually."
  fi
}

# Function to unblock websites
unblock_websites() {
  for website in "${websites_to_block[@]}"; do
    sed -i "/127.0.0.1 $website/d" /etc/hosts
    sed -i "/127.0.0.1 www.$website/d" /etc/hosts
  done

  # Flush DNS cache (Linux distribution dependent)
  if command -v systemctl >/dev/null && systemctl is-active --quiet NetworkManager; then
    systemctl restart NetworkManager
  elif command -v service >/dev/null && service networking restart; then
    service networking restart
  elif command -v /etc/init.d/networking restart; then
    /etc/init.d/networking restart
  else
    echo "Failed to flush DNS cache. You may need to do it manually."
  fi
}

# Main script
block_websites
echo "Websites are blocked for $block_duration_minutes minutes."

# Run the unblock function in the background and disown it
(sleep $block_duration_seconds && unblock_websites) & disown

exit 0
