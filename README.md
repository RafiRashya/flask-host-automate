
# Virtual Hosting Setup with Flask

This project automates the setup of a virtual hosting environment for Flask applications. It includes a web interface to input credentials and a script to configure and deploy the application.

## Prerequisites

- Ubuntu Server (22.04 or later)
- Python 3
- MySQL
- Nginx
- Bind9

## Getting Started

Follow these steps to set up and use the project.

### 1. Run the Monitor and Setup Script

Install `inotify-tools` with apt package:

```bash
sudo apt-get install -y inotify-tools
```

Run the `monitor.sh` script, This script will read the credentials from `credentials.txt`, install necessary services, and configure the environment.

```bash
chmod +x monitor.sh
sudo nohup bash monitor.sh &
```

### 2. Set Up the Flask Web Interface

Navigate to the `flask-host-automate` directory and start the Flask application:

```bash
python3 app.py
```

This will start a Flask web application that runs on `http://127.0.0.1:5000`.

### 3. Input Credentials

Open your web browser and navigate to `http://127.0.0.1:5000`. Fill in the following fields with the necessary information:
- GitHub Repository Link
- Database User
- User Password
- Database Name
- Domain

Submit the form to save the credentials.

### 4. Check Notification

The setup script will create a file `notification.txt` with the status of the deployment. Check this file to see if your web application is accessible.

```bash
cat notification.txt
```

or check notification on the web interface

### Stopping the Monitor Script

If you need to stop the `monitor.sh` script, use the following commands:

```bash
kill -9 $(ps aux | grep monitor.sh | grep -v grep | awk '{print $2}')
```

### Reset the hosted app

if you need to reset your hosted app, run the `reset.sh` file:

```bash
chmod +x reset.sh
./reset.sh
```

it will stop your hosted app and remove the directories.
