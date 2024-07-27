from flask import Flask, render_template, request, redirect, url_for, jsonify
import os

app = Flask(__name__)

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        github_link = request.form['github_link']
        db_user = request.form['db_user']
        user_pass = request.form['user_pass']
        db_name = request.form['db_name']
        domain = request.form['domain']

        with open('credentials.txt', 'w') as f:
            f.write(f"GitHub Link: {github_link}\n")
            f.write(f"Database User: {db_user}\n")
            f.write(f"User Password: {user_pass}\n")
            f.write(f"Database Name: {db_name}\n")
            f.write(f"Domain: {domain}\n")
            f.write("="*40 + "\n")

        return redirect(url_for('index'))
    return render_template('index.html')

@app.route('/notification')
def notification():
    if os.path.exists('notification.txt'):
        with open('notification.txt') as f:
            message = f.read()
    else:
        message = "No notification available."
    return jsonify(message=message)

if __name__ == '__main__':
    app.run(debug=True)
