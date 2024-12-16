#!/bin/bash

# Colors and Effects
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
RESET="\033[0m"
BOLD="\033[1m"

# Function to display mining progress
function mining_animation() {
  echo -ne "${YELLOW}${BOLD}Starting mining session...${RESET}\n"
  while :; do
    echo -ne "${MAGENTA}Mining${RESET}"
    for i in {1..3}; do
      echo -ne "."
      sleep 0.5
    done
    echo -ne "\r"
  done
}

# Function to display Bitcoin price tracker
function bitcoin_price_tracker() {
  curl -s "https://api.coindesk.com/v1/bpi/currentprice.json" | jq '.bpi.USD.rate' | sed 's/"//g'
}

# Function to get balance and earnings via PHP script
function get_balance_earnings() {
  local btc_address="$1"
  php -r "
    \$btc_address = '$btc_address';
    \$balance_json = file_get_contents('https://blockchain.info/q/addressbalance/' . \$btc_address);
    \$balance = \$balance_json / 100000000;
    echo \$balance;
  "
}

# Input Bitcoin Address
echo -e "\033[1;32mEnter your valid Bitcoin address for mining:\033[0m"
read -p "BTC Address: " BTC_ADDRESS

# Validate the Bitcoin address (basic validation)
if ! [[ "$BTC_ADDRESS" =~ ^[13]|^bc1 ]]; then
    echo "Invalid Bitcoin address. Please restart and enter a valid one."
    exit 1
fi

# Mining Configuration
DIFFICULTY=4 # Number of leading zeros required in the hash
NONCE=0      # Starting nonce value
TARGET="$(printf '0%.0s' $(seq 1 $DIFFICULTY))" # Leading zeros target

# Fetch initial balance using the PHP function
BALANCE=$(get_balance_earnings "$BTC_ADDRESS")
EARNINGS=0   # Earnings in BTC

# Multi-pool configurations
declare -A pools=(
    ["1"]="solo.antpool.com:3333"
    ["2"]="stratum.antpool.com:443"
    ["3"]="stratum+tcp://cn.ss.btc.com:3333"
)

# Connect to Bitcoin network and mining pools
echo -e "\033[1;34mConnecting to Bitcoin network...\033[0m"
echo -e "\033[1;34mConnected to Bitcoin network!\033[0m"

# Start connecting to mining pools
for pool in "${!pools[@]}"; do
    url="${pools[$pool]}"
    
    echo -e "\033[1;34mConnecting to mining pool: $url...\033[0m"
    echo -e "\033[1;32mSuccessfully connected to pool: $url!\033[0m"

    # Start mining process
    echo -e "\033[1;33mStarting mining...\033[0m"

    # Initialize hash rate variables
    START_TIME=$(date +%s)
    HASH_COUNT=0
    HASH_PER_TEN_MINUTES=0
    END_TIME=$((START_TIME + 600)) # 10 minutes from start

    while true; do
        NONCE=$((NONCE + 1))
        DATA="CryptographicPuzzle:$BTC_ADDRESS:$NONCE"
        HASH=$(echo -n "$DATA" | sha256sum | awk '{print $1}')

        # Increment hash count
        HASH_COUNT=$((HASH_COUNT + 1))

        # Check if we have reached the 10 minute mark
        if (( $(date +%s) >= END_TIME )); then
            HASH_PER_TEN_MINUTES=$HASH_COUNT
            echo -e "\nHash Rate: $HASH_PER_TEN_MINUTES hashes in 10 minutes."
            HASH_COUNT=0
            END_TIME=$((END_TIME + 600)) # Reset the 10-minute timer
        fi
        
        # Display current balance and hash
        echo -e "\r\033[1;32mNonce: $NONCE | Hash: $HASH | Current Balance: $BALANCE BTC | Earned this minute: $EARNINGS BTC\033[0m"
        
        # Check if hash meets the difficulty
        if [[ "$HASH" == $TARGET* ]]; then
            echo -e "\n\033[1;32mBlock mined successfully on pool $url! Nonce: $NONCE | Hash: $HASH\033[0m"
            BALANCE=$(get_balance_earnings "$BTC_ADDRESS")
            EARNINGS=$(($EARNINGS + 1))  
            echo -e "\033[1;36mTotal Balance: $BALANCE BTC | Earnings: $EARNINGS BTC\033[0m"
            
            # Check if goal reached
            if (( $(echo "$BALANCE >= 100" | bc -l) )); then
                echo -e "\033[1;32mMining complete! Total Balance: $BALANCE BTC\033[0m"
                break
            fi

            # Option to continue mining or withdraw
            echo -e "\033[1;34mDo you want to continue mining on this pool? (y/n):\033[0m"
            read -p "> " CHOICE
            
            if [[ "$CHOICE" == "y" ]]; then
                # Display Bitcoin price tracker every minute 
                bitcoin_price_tracker
                sleep 60
                continue
            else
                # Show the total mining time
                TOTAL_TIME=$(( $(date +%s) - START_TIME ))
                echo -e "\nTotal Mining Time: ${GREEN}$TOTAL_TIME seconds${RESET}"
                break
            fi
        fi
    done
done

# Withdrawal section for PHP integration
echo -e "\nDo you want to withdraw your earned Bitcoin? (y/n):\033[0m"
read -p "> " CHOICE
    
if [[ "$CHOICE" == "y" ]]; then
    # Enter your valid bitcoin address again 
    read -p "Enter your valid Bitcoin address for withdrawal:\033[0m" WITHDRAW_ADDRESS
    
    # Validate the Bitcoin address (basic validation)
    if ! [[ "$WITHDRAW_ADDRESS" =~ ^[13]|^bc1 ]]; then
        echo "Invalid Bitcoin address. Please restart and enter a valid one."
        exit 1
    fi
    
    # Call a PHP script to handle the withdrawal
    php -r "
        \$withdraw_address = '$WITHDRAW_ADDRESS';
        \$amount = $EARNINGS;
        // Here you would implement your BTC withdrawal API call.
        // This is a placeholder for demonstration purposes.
        echo 'Withdrawal of ' . \$amount . ' BTC to ' . \$withdraw_address . ' successfully initiated.';
    "
else
    echo -e "\nYou chose not to withdraw your earned Bitcoin."
fi

# Option to restart or exit program
echo -e "\nWhat would you like to do? (y/n):\033[0m"
read -p "> " CHOICE
    
if [[ "$CHOICE" == "y" ]]; then
    # Restart mining 
    clear
elif [[ "$CHOICE" == "n" ]]; then
    # Exit program 
    exit 0
fi

exit 0
