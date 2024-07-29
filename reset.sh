kill -9 $(ps aux | grep monitor.sh | grep -v grep | awk '{print $2}')
kill -9 $(lsof -t -i :8080)
sudo rm -rf ./guestbook
sudo rm -rf /etc/nginx/sites-available/* /etc/nginx/sites-enabled/* /etc/bind/zones/*
sudo systemctl restart nginx
sudo systemctl restart bind9