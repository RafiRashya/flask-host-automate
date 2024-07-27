#!/bin/bash

NOTIFICATION_FILE="notification.txt"

# Function to check and install required services
check_and_install_services() {
    local services=("mysql-server" "nginx" "bind9")
    local service_names=("mysql" "nginx" "named")
    local missing_services=()

    for ((i=0; i<${#services[@]}; i++)); do
        if ! command -v ${service_names[i]} &> /dev/null; then
            missing_services+=(${services[i]})
        fi
    done

    if [ ${#missing_services[@]} -eq 0 ]; then
        echo "All required services are already installed"
    else
        echo "Installing missing services: ${missing_services[@]}"
        sudo apt-get update
        sudo apt-get install -y "${missing_services[@]}"

        sudo systemctl start mysql nginx bind9
        sudo systemctl enable mysql nginx bind9
    fi
}

# Function to read credentials from file
read_credentials() {
    declare -A credentials
    while IFS= read -r line; do
        key="${line%%:*}"
        value="${line#*: }"
        credentials[$key]="$value"
    done < credentials.txt

    GITHUB_LINK="${credentials['GitHub Link']}"
    DB_USER="${credentials['Database User']}"
    USER_PASS="${credentials['User Password']}"
    DB_NAME="${credentials['Database Name']}"
    DOMAIN="${credentials['Domain']}"
}

# Function to setup MySQL
setup_mysql() {
    echo "Creating MySQL database and user..."
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
    sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${USER_PASS}';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
    sudo mysql -e "FLUSH PRIVILEGES;"
}

# Function to configure DNS with bind9
setup_bind9() {
    echo "Configuring DNS with bind9..."
    local zone_file="/etc/bind/zones/db.${DOMAIN}"
    sudo mkdir -p /etc/bind/zones

    sudo tee $zone_file > /dev/null <<EOF
\$TTL    604800
@       IN      SOA     ns1.${DOMAIN}. admin.${DOMAIN}. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.${DOMAIN}.
@       IN      A       127.0.0.1
@       IN      AAAA    ::1
ns1     IN      A       127.0.0.1
EOF

    if ! grep -q "zone \"${DOMAIN}\"" /etc/bind/named.conf.local; then
        sudo tee -a /etc/bind/named.conf.local > /dev/null <<EOF

zone "${DOMAIN}" {
    type master;
    file "/etc/bind/zones/db.${DOMAIN}";
};
EOF
    else
        echo "Zone ${DOMAIN} already exists in named.conf.local"
    fi

    sudo systemctl restart bind9
}

# Function to setup Nginx
setup_nginx() {
    echo "Configuring Nginx reverse proxy..."
    local revprox_file="/etc/nginx/sites-available/${DOMAIN}"

    sudo tee $revprox_file > /dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8080; # Port aplikasi Flask
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    sudo ln -sf $revprox_file /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl restart nginx
}

# Function to setup Flask application
setup_flask_app() {
    echo "Cloning GitHub repository..."
    local repo_name
    repo_name=$(basename -s .git "$GITHUB_LINK")

    git clone ${GITHUB_LINK} "$repo_name"
    cd "$repo_name" || exit

    echo "Installing dependencies..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt

    echo "Starting Flask application..."
    nohup python3 app.py &

    cd ..
}

# Function to write notification after checking web accessibility
write_notification() {
    local retry_count=5
    local wait_time=5

    echo "Checking if the web is accessible..."

    for ((i=1; i<=retry_count; i++)); do
        if curl -s --head "http://${DOMAIN}" | grep "200 OK" > /dev/null; then
            echo "Web is now accessible at http://${DOMAIN}" > $NOTIFICATION_FILE
            return 0
        else
            echo "Attempt $i: Web not accessible yet. Retrying in $wait_time seconds..."
            sleep $wait_time
        fi
    done

    echo "Failed to access web at http://${DOMAIN} after $retry_count attempts." > $NOTIFICATION_FILE
    return 1
}

# Main script execution
check_and_install_services
read_credentials
setup_mysql
setup_bind9
setup_nginx
setup_flask_app

if write_notification; then
    echo "Setup complete! Notification written to $NOTIFICATION_FILE."
else
    echo "Setup complete, but web is not accessible. Notification written to $NOTIFICATION_FILE."
fi

echo "Setup complete!"
