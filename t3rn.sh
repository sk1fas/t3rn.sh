#!/bin/bash

# Цвета текста
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Нет цвета

# Проверка curl
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi
sleep 1

# Логотип
curl -s https://raw.githubusercontent.com/sk1fas/logo-sk1fas/main/logo-sk1fas.sh | bash

# Проверка bc
if ! command -v bc &> /dev/null; then
    sudo apt update
    sudo apt install bc -y
fi
sleep 1

# Проверка версии Ubuntu
UBUNTU_VERSION=$(lsb_release -rs)
REQUIRED_VERSION=22.04
if (( $(echo "$UBUNTU_VERSION < $REQUIRED_VERSION" | bc -l) )); then
    echo -e "${RED}Для этой ноды нужна минимальная версия Ubuntu 22.04${NC}"
    exit 1
fi

# Меню
echo -e "${YELLOW}Выберите действие:${NC}"
echo -e "${CYAN}1) Установка ноды${NC}"
echo -e "${CYAN}2) Обновление ноды${NC}"
echo -e "${CYAN}3) Проверка логов${NC}"
echo -e "${CYAN}4) Рестарт ноды${NC}"
echo -e "${CYAN}5) Удаление ноды${NC}"
echo -e "${YELLOW}Введите номер:${NC} "
read choice

setup_executor_config() {
    CONFIG_FILE="$1"
    echo "ENVIRONMENT=testnet" > "$CONFIG_FILE"
    echo "EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=false" >> "$CONFIG_FILE"
    echo "EXECUTOR_PROCESS_ORDERS_API_ENABLED=false" >> "$CONFIG_FILE"
    echo "EXECUTOR_PROCESS_BIDS_BATCH=true" >> "$CONFIG_FILE"
    echo "EXECUTOR_ENABLE_BATCH_BIDDING=true" >> "$CONFIG_FILE"
    echo "LOG_LEVEL=debug" >> "$CONFIG_FILE"
    echo "LOG_PRETTY=false" >> "$CONFIG_FILE"
    echo "EXECUTOR_PROCESS_BIDS_ENABLED=true" >> "$CONFIG_FILE"
    echo "EXECUTOR_PROCESS_ORDERS=true" >> "$CONFIG_FILE"
    echo "EXECUTOR_PROCESS_CLAIMS=true" >> "$CONFIG_FILE"
    echo "PRIVATE_KEY_LOCAL=" >> "$CONFIG_FILE"
    echo "EXECUTOR_MAX_L3_GAS_PRICE=1500" >> "$CONFIG_FILE"
    echo "ENABLED_NETWORKS='arbitrum-sepolia,base-sepolia,optimism-sepolia,l2rn,unichain-sepolia,blast-sepolia'" >> "$CONFIG_FILE"

    if ! grep -q "NETWORKS_DISABLED=" "$CONFIG_FILE"; then
        echo "NETWORKS_DISABLED='monad-testnet,arbitrum,base,optimism,sei-testnet'" >> "$CONFIG_FILE"
    fi

    cat <<'EOF' >> "$CONFIG_FILE"
RPC_ENDPOINTS='{
    "l2rn": ["https://t3rn-b2n.blockpi.network/v1/rpc/public", "https://b2n.rpc.caldera.xyz/http"],
    "arbt": ["https://arbitrum-sepolia.drpc.org", "https://sepolia-rollup.arbitrum.io/rpc"],
    "bast": ["https://base-sepolia-rpc.publicnode.com", "https://base-sepolia.drpc.org"],
    "blst": ["https://sepolia.blast.io", "https://blast-sepolia.drpc.org"],
    "mont": ["https://testnet-rpc.monad.xyz"],
    "opst": ["https://sepolia.optimism.io", "https://optimism-sepolia.drpc.org"],
    "unit": ["https://unichain-sepolia.drpc.org", "https://sepolia.unichain.org"]
}'
EOF
}

case $choice in
    1|2)
        echo -e "${BLUE}${choice} - Установка/обновление ноды t3rn...${NC}"

        [ "$choice" = "2" ] && sudo systemctl stop t3rn && rm -rf ~/executor/

        sudo apt update && sudo apt upgrade -y
        EXECUTOR_URL="https://github.com/t3rn/executor-release/releases/download/v0.65.0/executor-linux-v0.65.0.tar.gz"
        curl -L -o executor.tar.gz "$EXECUTOR_URL"
        tar -xzvf executor.tar.gz && rm executor.tar.gz

        USERNAME=$(whoami)
        HOME_DIR=$(eval echo ~$USERNAME)
        CONFIG_FILE="$HOME_DIR/executor/executor/bin/.t3rn"

        setup_executor_config "$CONFIG_FILE"

        echo -e "${YELLOW}Введите ваш приватный ключ:${NC}"
        read PRIVATE_KEY
        sed -i "s|PRIVATE_KEY_LOCAL=|PRIVATE_KEY_LOCAL=$PRIVATE_KEY|" "$CONFIG_FILE"

        sudo bash -c "cat <<EOT > /etc/systemd/system/t3rn.service
[Unit]
Description=t3rn Service
After=network.target

[Service]
EnvironmentFile=$HOME_DIR/executor/executor/bin/.t3rn
ExecStart=$HOME_DIR/executor/executor/bin/executor
WorkingDirectory=$HOME_DIR/executor/executor/bin/
Restart=on-failure
User=$USERNAME

[Install]
WantedBy=multi-user.target
EOT"

        sudo systemctl daemon-reload
        sudo systemctl restart systemd-journald
        sudo systemctl enable t3rn
        sudo systemctl start t3rn
        sleep 2

        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${YELLOW}Команда для проверки логов:${NC}"
        echo "sudo journalctl -u t3rn -f"
        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${GREEN}Sk1fas Journey — вся крипта в одном месте!${NC}"
        echo -e "${CYAN}Наш Telegram https://t.me/Sk1fasCryptoJourney${NC}"
        sudo journalctl -u t3rn -f
        ;;
    3)
        sudo journalctl -u t3rn -f
        ;;
    4)
        sudo systemctl restart t3rn
        sudo journalctl -u t3rn -f
        ;;
    5)
        sudo systemctl stop t3rn
        sudo systemctl disable t3rn
        sudo rm /etc/systemd/system/t3rn.service
        sudo systemctl daemon-reload
        rm -rf ~/executor
        echo -e "${GREEN}Нода t3rn успешно удалена!${NC}"
        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${GREEN}Sk1fas Journey — вся крипта в одном месте!${NC}"
        echo -e "${CYAN}Наш Telegram https://t.me/Sk1fasCryptoJourney${NC}"
        ;;
    *)
        echo -e "${RED}Неверный выбор. Пожалуйста, введите номер от 1 до 5.${NC}"
        ;;
esac
