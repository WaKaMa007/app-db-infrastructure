#!/bin/bash
# User data script for Client Management Application
# This script sets up a Flask application to manage client information

# Don't use 'set -e' - we want to continue even if some commands fail
# Use || true for commands that can safely fail
set -u  # Only exit on undefined variables
set -o pipefail  # Exit on pipe failures

echo "=== Starting Client Management Application Setup ==="

# Update system and install Python
echo "Updating system packages..."
sudo apt update -y
sudo apt install -y python3 python3-pip

# Install and start SSM Agent for Session Manager connectivity
echo "Installing and starting SSM Agent..."
if ! command -v amazon-ssm-agent &> /dev/null; then
    echo "SSM Agent not found, installing via snap..."
    sudo snap install amazon-ssm-agent --classic || {
        echo "⚠️  Snap install failed, trying alternative method..."
        # Alternative: Install from deb package if snap fails
        cd /tmp
        wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
        sudo dpkg -i amazon-ssm-agent.deb || sudo apt-get install -f -y
        rm -f amazon-ssm-agent.deb
    }
fi

# Start SSM Agent
echo "Starting SSM Agent..."
sudo systemctl enable amazon-ssm-agent || sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service || true
sudo systemctl start amazon-ssm-agent || sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service || sudo snap start amazon-ssm-agent || true

# Verify SSM Agent is running
sleep 2
if sudo systemctl is-active --quiet amazon-ssm-agent || sudo systemctl is-active --quiet snap.amazon-ssm-agent.amazon-ssm-agent.service; then
    echo "✅ SSM Agent is running"
else
    echo "⚠️  SSM Agent may not be running, check logs with: sudo journalctl -u amazon-ssm-agent"
fi

# Stop Apache if installed (to avoid port 80 conflict)
sudo systemctl stop apache2 || true
sudo systemctl disable apache2 || true

# Install Python packages for PostgreSQL
echo "Installing Python packages (Flask, psycopg2-binary, boto3)..."
sudo -H pip3 install flask psycopg2-binary boto3 || {
    echo "⚠️  pip3 install failed, trying with --break-system-packages..."
    sudo -H pip3 install --break-system-packages flask psycopg2-binary boto3
}

# Verify installation
echo "Verifying Python packages..."
python3 -c "import flask; import psycopg2; import boto3; print('✅ All packages installed successfully')" || {
    echo "❌ Package verification failed, trying alternative installation..."
    sudo apt-get install -y python3-flask python3-psycopg2 python3-boto3 || true
    python3 -c "import flask; import psycopg2; import boto3; print('✅ Packages verified')" || echo "⚠️  Some packages may not be available"
}

# Create app directory
mkdir -p /home/ubuntu/webapp
cd /home/ubuntu/webapp

# Copy the client application
# Note: In production, you'd want to pull this from a Git repository or S3
# For now, we'll create it inline
cat << 'CLIENT_APP' > app.py
import os
import json
import boto3
from flask import Flask, request, render_template_string, redirect, url_for
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime

app = Flask(__name__)

# HTML Template
CLIENT_FORM_HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Client Information System</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
        .nav {
            text-align: center;
            margin-bottom: 30px;
        }
        .nav a {
            margin: 0 10px;
            padding: 8px 16px;
            text-decoration: none;
            background-color: #007bff;
            color: white;
            border-radius: 4px;
        }
        .nav a:hover {
            background-color: #0056b3;
        }
        form {
            display: grid;
            gap: 15px;
        }
        label {
            font-weight: bold;
            color: #555;
        }
        input[type="text"],
        input[type="email"],
        input[type="tel"],
        textarea {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
        }
        textarea {
            resize: vertical;
            min-height: 80px;
        }
        button {
            background-color: #28a745;
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        button:hover {
            background-color: #218838;
        }
        .success {
            background-color: #d4edda;
            color: #155724;
            padding: 15px;
            border-radius: 4px;
            margin-bottom: 20px;
        }
        .error {
            background-color: #f8d7da;
            color: #721c24;
            padding: 15px;
            border-radius: 4px;
            margin-bottom: 20px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #007bff;
            color: white;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .empty {
            text-align: center;
            color: #888;
            padding: 40px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📋 Client Information System</h1>
        <div class="nav">
            <a href="/">Add Client</a>
            <a href="/clients">View Clients</a>
            <a href="/health">Health Check</a>
        </div>
        {% if message %}
        <div class="{{ message_type }}">{{ message }}</div>
        {% endif %}
        {{ content|safe }}
    </div>
</body>
</html>
"""

FORM_CONTENT = """
<h2>Add New Client</h2>
<form method="POST" action="/">
    <div>
        <label for="name">Full Name *</label>
        <input type="text" id="name" name="name" required placeholder="John Doe">
    </div>
    
    <div>
        <label for="email">Email Address *</label>
        <input type="email" id="email" name="email" required placeholder="john@example.com">
    </div>
    
    <div>
        <label for="phone">Phone Number</label>
        <input type="tel" id="phone" name="phone" placeholder="+1 234-567-8900">
    </div>
    
    <div>
        <label for="company">Company</label>
        <input type="text" id="company" name="company" placeholder="Acme Inc.">
    </div>
    
    <div>
        <label for="address">Address</label>
        <textarea id="address" name="address" placeholder="123 Main St, City, State, ZIP"></textarea>
    </div>
    
    <div>
        <label for="notes">Notes</label>
        <textarea id="notes" name="notes" placeholder="Additional information"></textarea>
    </div>
    
    <button type="submit">Save Client</button>
</form>
"""


def get_db_credentials():
    secret_name = os.getenv("SECRET_NAME")
    region = os.getenv("AWS_REGION", "us-east-1")
    
    if not secret_name:
        raise ValueError("SECRET_NAME environment variable not set")
    
    client = boto3.client("secretsmanager", region_name=region)
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])


def get_db_connection():
    max_retries = 3
    retry_delay = 2
    
    for attempt in range(max_retries):
        try:
            creds = get_db_credentials()
            
            # PostgreSQL RDS requires SSL connections
            conn = psycopg2.connect(
                host=creds["host"],
                database=creds["dbname"],
                user=creds["username"],
                password=creds["password"],
                port=int(creds["port"]),
                connect_timeout=10,
                sslmode="require"  # RDS PostgreSQL requires SSL
            )
            
            print(f"✅ Database connection successful (attempt {attempt + 1})")
            return conn
            
        except psycopg2.OperationalError as e:
            if "password authentication failed" in str(e).lower() or "access denied" in str(e).lower():
                print(f"❌ Database access denied: {e}")
                raise Exception(f"Database access denied: {e}")
            elif attempt < max_retries - 1:
                print(f"⚠️  Connection attempt {attempt + 1} failed, retrying...")
                import time
                time.sleep(retry_delay)
                continue
            else:
                raise Exception(f"Database connection failed: {e}")
        except Exception as e:
            print(f"❌ Database connection error: {e}")
            if attempt < max_retries - 1:
                import time
                time.sleep(retry_delay)
                continue
            raise


def init_database():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS clients (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                email VARCHAR(255) NOT NULL,
                phone VARCHAR(50),
                company VARCHAR(255),
                address TEXT,
                notes TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT unique_email UNIQUE (email)
            )
        """)
        
        # Create indexes
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_email ON clients(email)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_name ON clients(name)")
        
        # Create trigger for updated_at (PostgreSQL equivalent of ON UPDATE CURRENT_TIMESTAMP)
        cursor.execute("""
            CREATE OR REPLACE FUNCTION update_updated_at_column()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = CURRENT_TIMESTAMP;
                RETURN NEW;
            END;
            $$ language 'plpgsql';
        """)
        cursor.execute("""
            DROP TRIGGER IF EXISTS update_clients_updated_at ON clients;
            CREATE TRIGGER update_clients_updated_at
                BEFORE UPDATE ON clients
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
        """)
        
        conn.commit()
        cursor.close()
        conn.close()
        
        print("✅ Database table initialized successfully")
        return True
        
    except psycopg2.OperationalError as e:
        error_msg = str(e)
        print(f"⚠️  Database connection error: {error_msg}")
        print(f"   Check: Security group, network connectivity, credentials")
        return False
    except psycopg2.Error as e:
        error_msg = str(e)
        print(f"⚠️  Database error: {error_msg}")
        return False
    except Exception as e:
        error_msg = str(e)
        print(f"⚠️  Database initialization error: {error_msg}")
        print(f"   Error type: {type(e).__name__}")
        import traceback
        print(f"   Traceback: {traceback.format_exc()}")
        return False


@app.route("/", methods=["GET", "POST"])
def index():
    # Handle POST request (form submission)
    if request.method == "POST":
        try:
            name = request.form.get("name", "").strip()
            email = request.form.get("email", "").strip()
            phone = request.form.get("phone", "").strip()
            company = request.form.get("company", "").strip()
            address = request.form.get("address", "").strip()
            notes = request.form.get("notes", "").strip()
            
            if not name or not email:
                return render_template_string(
                    CLIENT_FORM_HTML,
                    content=FORM_CONTENT,
                    message="Error: Name and Email are required fields.",
                    message_type="error"
                )
            
            # Try to initialize database and get the actual error if it fails
            db_init_result = init_database()
            if not db_init_result:
                # Get the last error from logs or try connection again to get error
                try:
                    conn = get_db_connection()
                    conn.close()
                    # If connection works, try init again
                    if not init_database():
                        raise Exception("Failed to initialize database (connection works but init failed)")
                except Exception as conn_err:
                    raise Exception(f"Failed to initialize database: {str(conn_err)}")
            
            conn = get_db_connection()
            cursor = conn.cursor()
            
            try:
                cursor.execute("""
                    INSERT INTO clients (name, email, phone, company, address, notes)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (name, email, phone or None, company or None, address or None, notes or None))
                
                result = cursor.fetchone()
                client_id = result[0] if result else None
                conn.commit()
                
                cursor.close()
                conn.close()
                
                success_msg = f"✅ Client '{name}' has been successfully added! (ID: {client_id})"
                return render_template_string(
                    CLIENT_FORM_HTML,
                    content=FORM_CONTENT,
                    message=success_msg,
                    message_type="success"
                )
                
            except psycopg2.IntegrityError as e:
                conn.rollback()
                cursor.close()
                conn.close()
                return render_template_string(
                    CLIENT_FORM_HTML,
                    content=FORM_CONTENT,
                    message="Error: A client with this email already exists.",
                    message_type="error"
                )
            except Exception as e:
                conn.rollback()
                cursor.close()
                conn.close()
                raise
                
        except Exception as e:
            error_msg = f"Error saving client: {str(e)}"
            print(f"❌ {error_msg}")
            return render_template_string(
                CLIENT_FORM_HTML,
                content=FORM_CONTENT,
                message=error_msg,
                message_type="error"
            ), 500
    
    # Handle GET request (display form)
    return render_template_string(CLIENT_FORM_HTML, content=FORM_CONTENT)


@app.route("/clients")
def list_clients():
    try:
        # Try to initialize database and get the actual error if it fails
        db_init_result = init_database()
        if not db_init_result:
            # Get the last error from logs or try connection again to get error
            try:
                conn = get_db_connection()
                conn.close()
                # If connection works, try init again
                if not init_database():
                    raise Exception("Failed to initialize database (connection works but init failed)")
            except Exception as conn_err:
                raise Exception(f"Failed to initialize database: {str(conn_err)}")
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("""
            SELECT id, name, email, phone, company, address, notes, 
                   created_at, updated_at
            FROM clients
            ORDER BY created_at DESC
        """)
        
        clients = cursor.fetchall()
        cursor.close()
        conn.close()
        
        if not clients:
            content = '<div class="empty"><h2>No clients found</h2><p>Start by adding a new client.</p></div>'
            return render_template_string(CLIENT_FORM_HTML, content=content)
        
        table_html = """
        <h2>📋 All Clients ({} total)</h2>
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Phone</th>
                    <th>Company</th>
                    <th>Created</th>
                </tr>
            </thead>
            <tbody>
        """.format(len(clients))
        
        for client in clients:
            created_at = client['created_at'].strftime('%Y-%m-%d %H:%M') if client['created_at'] else 'N/A'
            table_html += f"""
                <tr>
                    <td>{client['id']}</td>
                    <td><strong>{client['name']}</strong></td>
                    <td>{client['email']}</td>
                    <td>{client['phone'] or '-'}</td>
                    <td>{client['company'] or '-'}</td>
                    <td>{created_at}</td>
                </tr>
            """
        
        table_html += """
            </tbody>
        </table>
        """
        
        return render_template_string(CLIENT_FORM_HTML, content=table_html)
        
    except Exception as e:
        error_msg = f"Error retrieving clients: {str(e)}"
        print(f"❌ {error_msg}")
        return render_template_string(
            CLIENT_FORM_HTML,
            content=f'<div class="error">{error_msg}</div>',
            message_type="error"
        ), 500


@app.route("/health")
def health():
    # Health check endpoint - MUST NOT require database access
    # ALB health checks will fail if this endpoint requires DB connection
    # Returns 200 OK if Flask app is running (simple check)
    return {
        "status": "healthy",
        "service": "running",
        "timestamp": datetime.now().isoformat()
    }, 200


if __name__ == "__main__":
    try:
        print("=== Client Management Application Starting ===")
        
        # Start Flask IMMEDIATELY - don't block on database initialization
        # Database will be initialized lazily on first request that needs it
        # This ensures health checks work even if database is not ready
        import threading
        
        def init_db_async():
            """Initialize database in background thread"""
            try:
                import time
                time.sleep(5)  # Give Flask time to start first
                print("Attempting database initialization in background...")
                init_database()
                print("✅ Database initialized successfully")
            except Exception as e:
                print(f"⚠️  Database initialization failed (will retry on first request): {e}")
        
        # Start database initialization in background thread
        db_thread = threading.Thread(target=init_db_async, daemon=True)
        db_thread.start()
        
        print("✅ Flask application starting (health check available immediately)")
        print("   Flask will listen on 0.0.0.0:80")
        app.run(host="0.0.0.0", port=80, debug=False, threaded=True)
    except Exception as e:
        print(f"❌ CRITICAL: Flask failed to start: {e}")
        import traceback
        traceback.print_exc()
        raise
CLIENT_APP

# Install authbind to allow non-root user to bind to port 80
sudo apt-get install -y authbind

# Allow ubuntu user to bind to port 80
sudo touch /etc/authbind/byport/80
sudo chmod 500 /etc/authbind/byport/80
sudo chown ubuntu:ubuntu /etc/authbind/byport/80

# Create systemd service for Flask
cat << SERVICE | sudo tee /etc/systemd/system/flaskapp.service
[Unit]
Description=Client Management Flask Application
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/webapp
Environment="SECRET_NAME=${secret_arn}"
Environment="AWS_REGION=${region}"
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
ExecStart=/usr/bin/authbind --deep /usr/bin/python3 /home/ubuntu/webapp/app.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
SERVICE

# Enable and start Flask service
sudo systemctl daemon-reload
sudo systemctl enable flaskapp

# Start Flask service
echo "Starting Flask application..."
sudo systemctl start flaskapp
sleep 10

# Verify Flask is running
if sudo systemctl is-active --quiet flaskapp; then
    echo "✅ Flask service is running"
    sleep 2
    if curl -f http://localhost/health > /dev/null 2>&1; then
        echo "✅ Health endpoint is responding"
    else
        echo "⚠️  Health endpoint not responding yet, checking logs..."
        sudo journalctl -u flaskapp --no-pager -n 20 || true
    fi
else
    echo "❌ Flask service failed to start"
    echo "Checking logs for errors..."
    sudo journalctl -u flaskapp --no-pager -n 50 || true
    echo ""
    echo "⚠️  Flask service failed, but continuing userdata script..."
    echo "Service will be retried by systemd with Restart=on-failure"
    echo "You can check logs later with: sudo journalctl -u flaskapp -f"
fi

echo "=== Client Management Application Setup Complete ==="