#!/bin/bash

# TODO
#     sites from file
#     hide process
#     test on linux
#     test on mac
#     block apps


# Check root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root using sudo."
  exit 1
fi

OS="$(uname)"

# Defaults
DURATION=$((60 * 8))
SITES=()

show_help() {
    echo "Usage: $0 [-d DURATION] [-h]"
    echo
    echo "  -d, --duration  Set the duration for the script in minutes."
    echo "                  Default is 480 minutes (8 hours)."
    echo "                  The value must be between 1 and 1920."
    echo
    echo "  -h, --help      Display this help message and exit."
    exit 0
}

# Function to display an error message and exit
error_message_duration() {
    echo "Error: Duration must be between 1 minute and 24 hours."
    exit 1
}

# Function to parse the arguments
parse_args() {
  while [[ "$#" -gt 0 ]]; do
      case $1 in
          -d|--duration)
              DURATION="$2"; shift ;;
          -h|--help)
              show_help ;;
          -s|--sites)
                      shift
                      while [[ "$#" -gt 0 ]] && ! [[ "$1" =~ ^- ]]; do
                          SITES+=("$1")
                          shift
                      done
                      continue
                      ;;
          *)
              echo "Unknown parameter: $1"; exit 1 ;;
      esac
      shift
  done
}

validate_parse_args() {
    if [[ -z "$DURATION" ]] || ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then
        error_message_duration
    fi

    if [ "$DURATION" -lt 1 ] || [ "$DURATION" -gt $((24 * 8 * 60)) ]; then # > 24 hours must be mistake
        error_message_duration
    fi

    # if no sites
    if [ ${#SITES[@]} -eq 0 ]; then
        echo "No sites to block"
        exit 1
    fi
}

parse_args "$@"
validate_parse_args

# PRINT END TIME

if [ "$OS" = "Darwin" ]; then
        END_TIME=$(date -v +"${DURATION}"M '+%Y-%m-%d %H:%M')
    else
        END_TIME=$(date -d "+${DURATION} minutes" '+%Y-%m-%d %H:%M')
    fi

echo "Script will work until $END_TIME"


block_duration_seconds=$((DURATION * 60))

flush_dns() {
  if [[ "$OS" = "Darwin" ]]; then
    # For macOS
    sudo killall -HUP mDNSResponder && echo "Flushed DNS cache on macOS." || echo "Failed to flush DNS cache on macOS."
  else
    # For Linux
    if command -v systemctl >/dev/null && systemctl is-active --quiet NetworkManager; then
      sudo systemctl restart NetworkManager && echo "Flushed DNS cache on Linux (systemd)." || echo "Failed to flush DNS cache."
    elif command -v service >/dev/null && service --status-all | grep -q networking; then
      sudo service networking restart && echo "Flushed DNS cache on Linux (service)." || echo "Failed to flush DNS cache."
    elif [ -x /etc/init.d/networking ]; then
      sudo /etc/init.d/networking restart && echo "Flushed DNS cache on Linux (init.d)." || echo "Failed to flush DNS cache."
    else
      echo "Unable to detect DNS flushing method. Please flush DNS cache manually."
    fi
  fi
}

# Function to block websites
block_websites() {
  # Backup /etc/hosts
  sudo cp /etc/hosts /etc/hosts.ssc.backup

  # Initialize a new array for unblocked sites
  local unblocked_sites=()

  # Filter out already blocked sites
  for website in "${SITES[@]}"; do
    if ! grep -q "127.0.0.1 $website" /etc/hosts; then
      unblocked_sites+=("$website")
    fi
  done

  # Update SITES array to only include unblocked sites
  SITES=("${unblocked_sites[@]}")

  # Block the sites that are not already blocked
  for website in "${SITES[@]}"; do
    echo "Blocking $website..."
    echo "127.0.0.1 $website" | sudo tee -a /etc/hosts > /dev/null
    echo "127.0.0.1 www.$website" | sudo tee -a /etc/hosts > /dev/null
  done

  # Flush DNS cache if there were new sites to block
  if [ ${#SITES[@]} -gt 0 ]; then
    flush_dns
  else
    echo "No new sites to block."
    exit 0
  fi
}

# Function to unblock websites
unblock_websites() {
  for website in "${SITES[@]}"; do
    sed -i "/127.0.0.1 $website/d" /etc/hosts
    sed -i "/127.0.0.1 www.$website/d" /etc/hosts
  done

  flush_dns
}

check_if_websites_blocked() {
  local is_blocked_again=false

  for website in "${SITES[@]}"; do
    # Check if the website is blocked
    if ! grep -q "127.0.0.1 $website" /etc/hosts && ! grep -q "127.0.0.1 www.$website" /etc/hosts; then
      is_blocked_again=true
      echo "$website is not blocked. Blocking now..."
      # Block the website
      echo "127.0.0.1 $website" | sudo tee -a /etc/hosts > /dev/null
      echo "127.0.0.1 www.$website" | sudo tee -a /etc/hosts > /dev/null
    fi
  done

  if [ "$is_blocked_again" = true ]; then
    flush_dns
  fi
}

# Main script
block_websites

# Run the unblock function in the background and disown it
(
  end_time=$(($(date +%s) + block_duration_seconds))

  while [ "$(date +%s)" -lt $((end_time - 180)) ]; do
      check_if_websites_blocked
      sleep 5
  done

  sleep "$((end_time - $(date +%s)))"
  unblock_websites
) & disown

exit 0
