#!/bin/bash

NOTIFICATION_FILE="notification.txt"

# Memeriksa Layanan yang Dibutuhkan
if command -v mysql &> /dev/null && command -v nginx &> /dev/null && command -v named &> /dev/null; then
        echo "MySQL, nginx, dan bind9 sudah terinstal"
else
        echo "Beberapa layanan belum terinstal. Menginstal layanan yang dibutuhkan..."
        sudo apt-get update
        sudo apt-get install -y mysql-server nginx bind9
        sudo systemctl start mysql
        sudo systemctl enable mysql
        sudo systemctl start nginx
        sudo systemctl enable nginx
        sudo systemctl start bind9
        sudo systemctl enable bind9
fi

# Fungsi untuk membaca kredensial dari file
read_credentials() {
    while IFS= read -r line; do
        if [[ $line == GitHub\ Link:* ]]; then
            GITHUB_LINK="${line#GitHub Link: }"
        elif [[ $line == Database\ User:* ]]; then
            DB_USER="${line#Database User: }"
        elif [[ $line == User\ Password:* ]]; then
            USER_PASS="${line#User Password: }"
        elif [[ $line == Database\ Name:* ]]; then
            DB_NAME="${line#Database Name: }"
        elif [[ $line == Domain:* ]]; then
            DOMAIN="${line#Domain: }"
        fi
    done < credentials.txt
}

# Fungsi untuk menginstal dan mengonfigurasi MySQL
setup_mysql() {
    echo "Creating MySQL database and user..."
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
    sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${USER_PASS}';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
    sudo mysql -e "FLUSH PRIVILEGES;"
}

# Fungsi untuk mengonfigurasi DNS dengan bind9
setup_bind9() {
    echo "Configuring DNS with bind9..."

    # Konfigurasi file zona
    ZONE_FILE="/etc/bind/zones/db.${DOMAIN}"
    sudo mkdir -p /etc/bind/zones

    # Buat konfigurasi zona
    sudo tee $ZONE_FILE > /dev/null <<EOF
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

    # Tambahkan zona ke konfigurasi named.conf.local jika belum ada
    if ! grep -q "zone \"${DOMAIN}\"" /etc/bind/named.conf.local; then
        sudo bash -c "cat >> /etc/bind/named.conf.local <<EOF

zone \"${DOMAIN}\" {
    type master;
    file \"/etc/bind/zones/db.${DOMAIN}\";
};
EOF"
    else
        echo "Zone ${DOMAIN} already exists in named.conf.local"
    fi

    # Restart bind9
    sudo systemctl restart bind9
}

# Fungsi untuk menginstal dan mengonfigurasi Nginx
setup_nginx() {
    echo "Configuring Nginx reverse proxy..."
    REVPROX_FILE="/etc/nginx/sites-available/${DOMAIN}"

    # Buat konfigurasi Nginx
    sudo tee $REVPROX_FILE > /dev/null <<EOF
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

    # Aktifkan konfigurasi
    sudo ln -s $REVPROX_FILE /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl restart nginx
}

setup_flask_app() {
    echo "Cloning GitHub repository..."

    REPO_NAME=$(basename -s .git "$GITHUB_LINK")

    git clone ${GITHUB_LINK} "$REPO_NAME"
    cd "$REPO_NAME" || exit

    echo "Installing dependencies..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt

    echo "Starting Flask application..."
    nohup python3 app.py &

    cd ..
}

# Fungsi untuk menulis pesan notifikasi ke file setelah memeriksa aksesibilitas web
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

# Main script
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