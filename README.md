# Flask-EC2-Lab

# Flask on EC2: Manual Deployment vs. Terraform

**GRC Engineering Club — Bridging Compliance and Code**

This project demonstrates how to deploy a Python Flask web application on AWS EC2 first manually through the AWS Management Console, then using Terraform to automate the same infrastructure. The goal is to make the case for Infrastructure as Code (IaC) by showing exactly what you're automating and why it matters.

---

## Table of Contents

1. [Purpose & Background](#1-purpose--background)
2. [Prerequisites](#2-prerequisites)
3. [Part 1: Manual Deployment (AWS Console)](#3-part-1-manual-deployment-aws-console)
4. [Part 2: Cleanup](#4-part-2-cleanup)
5. [Part 3: Terraform Deployment](#5-part-3-terraform-deployment)
6. [Manual vs. Terraform — Side-by-Side Comparison](#6-manual-vs-terraform--side-by-side-comparison)
7. [Repository Structure](#7-repository-structure)
8. [GRC Control Mappings](#8-grc-control-mappings)

---

## 1. Purpose & Background

GRC (Governance, Risk, and Compliance) work is no longer confined to spreadsheets and PDF checklists. It lives inside CI/CD pipelines, cloud infrastructure, and automated workflows. This lab bridges that gap.

**What you'll learn:**

| Skill | GRC Application |
|---|---|
| EC2 provisioning | Assessing compute resources for compliance |
| Security groups | Network access controls (AC-4, SC-7) |
| SSH key management | Cryptographic access control (IA-2, IA-5) |
| Flask web framework | Building internal compliance tools and dashboards |
| Linux administration | Reviewing system configurations during audits |
| Terraform IaC | Codifying infrastructure for repeatability and audit trails |

**Why manual-first?** You need to understand what Terraform is automating before you automate it. Otherwise you're copying code without comprehension and that's useless when something breaks or when you're assessing whether someone else's infrastructure meets control requirements.

---

## 2. Prerequisites

### AWS Account
- [Create a free tier account](https://aws.amazon.com/free)
- **Immediately enable MFA on your root account** — IAM → Security credentials → Assign MFA device *(maps to IA-2(1))*
- Set a billing alert: Billing → Budgets → Create budget → Zero spend budget

### SSH Client by OS

| OS | Recommended Option |
|---|---|
| **Windows** | **PowerShell** (built-in, Windows 10+) — recommended for this lab. Alternatively: [Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/install) or [PuTTY](https://www.putty.org/) |
| **macOS** | Built-in Terminal |
| **Linux** | Built-in Terminal |

> **Windows users:** PowerShell on Windows 10/11 includes a built-in OpenSSH client that supports `.pem` keys directly — no PuTTY or key conversion needed. Open it by searching "PowerShell" in the Start menu. Run `ssh -V` to confirm it's available.

### Install & Configure AWS CLI

**macOS:**
```bash
brew install awscli
```

**Linux:**
```bash
sudo apt install awscli -y
```

**Windows (PowerShell — run as Administrator):**
```powershell
# Option 1: Using winget (Windows 10/11 built-in package manager)
winget install Amazon.AWSCLI

# Option 2: Download the MSI installer directly
# https://awscli.amazonaws.com/AWSCLIV2.msi
# Run the installer, then restart PowerShell
```

**Verify installation (all platforms):**
```bash
aws --version
```

**Configure AWS CLI (one-time setup — same on all platforms):**
```bash
aws configure
# Prompts: Access Key ID, Secret Access Key, Region (e.g. us-east-1), Output format (json)
```

> **Security note:** Credentials are stored in `~/.aws/credentials` (macOS/Linux) or `C:\Users\<YourName>\.aws\credentials` (Windows) — completely separate from this project folder. Never store access keys inside your Terraform directory, and never commit them to Git. This maps to IA-5, SC-12, and SC-28.

**Verify credentials work:**
```bash
aws sts get-caller-identity
```

### Install Terraform

**macOS:**
```bash
brew install terraform
```

**Linux:**
```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Windows (PowerShell — run as Administrator):**
```powershell
# Option 1: Using winget
winget install Hashicorp.Terraform

# Option 2: Using Chocolatey (if installed)
choco install terraform

# Option 3: Manual install
# Download the ZIP from https://developer.hashicorp.com/terraform/install
# Extract terraform.exe to C:\Windows\System32\ or any folder in your PATH
```

**Verify (all platforms):**
```bash
terraform -v
```

---

## 3. Part 1: Manual Deployment (AWS Console)

> ⏱️ **Expected time: 20–30 minutes of clicking, configuring, and troubleshooting.**
> This is intentional — feel it before you automate it.

---

### Step 1: Create a Key Pair

1. EC2 Dashboard → **Key Pairs** → **Create key pair**
2. Name: `grc-flask-lab-key` | Type: RSA
3. **Key format:**
   - **macOS/Linux:** Select `.pem`
   - **Windows (PowerShell):** Select `.pem` — PowerShell's built-in SSH supports `.pem` directly
   - **Windows (PuTTY only):** Select `.ppk`
4. The private key downloads automatically, so save it securely.

**macOS/Linux — set permissions and move the key:**
```bash
chmod 400 ~/Downloads/grc-flask-lab-key.pem
mv ~/Downloads/grc-flask-lab-key.pem ~/.ssh/
```

**Windows (PowerShell) — set permissions on the key:**

PowerShell requires you to restrict the `.pem` file before SSH will accept it. Run these commands, replacing `YourUsername` with your actual Windows username:

```powershell
# Create a dedicated SSH folder if it doesn't exist
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.ssh"

# Move key from Downloads to .ssh folder
Move-Item "$env:USERPROFILE\Downloads\grc-flask-lab-key.pem" "$env:USERPROFILE\.ssh\grc-flask-lab-key.pem"

# Fix permissions — remove inherited permissions and grant access only to your user
$keyPath = "$env:USERPROFILE\.ssh\grc-flask-lab-key.pem"
icacls $keyPath /inheritance:r
icacls $keyPath /grant:r "${env:USERNAME}:R"
```

> **Pain point #1:** You have to remember to do all of this manually. On macOS/Linux, forget `chmod 400` and SSH refuses with a cryptic error. On Windows, forget the `icacls` commands and you get: `WARNING: UNPROTECTED PRIVATE KEY FILE!` — and the connection fails.

*GRC note: Maps to IA-5 (Authenticator Management). In production, document key custody and implement rotation policies.*

---

### Step 2: Create a Security Group

1. EC2 Dashboard → **Security Groups** → **Create security group**
2. Name: `grc-flask-lab-sg` | VPC: Default

**Inbound Rules:**

| Type | Port | Source | Purpose |
|---|---|---|---|
| SSH | 22 | My IP | Console access (your IP only) |
| Custom TCP | 5000 | 0.0.0.0/0 | Flask application |

> **Pain point #2:** "My IP" is your current public IP. If you switch WiFi, connect to a VPN, or move networks, you'll be locked out and have to manually edit the rule. There's no automated way to keep this current when using the console.

> **Pain point #3:** Easy to misconfigure. Forget port 5000 and you'll SSH in fine but never load the app. Forget port 22 entirely and you can't connect at all. Common mistakes:

| Problem | Symptom | Fix |
|---|---|---|
| Forgot SSH rule | "Connection timed out" | Add inbound rule for port 22 |
| Your IP changed | "Connection timed out" after network switch | Edit rule, update source IP |
| Forgot port 5000 | SSH works but Flask app won't load | Add inbound rule for port 5000 |
| Wrong SG attached | All rules correct but still can't connect | Verify EC2 uses this security group |

*GRC note: Maps to SC-7 (Boundary Protection) and AC-4 (Information Flow Enforcement).*

---

### Step 3: Launch the EC2 Instance

1. EC2 Dashboard → **Instances** → **Launch instances**
2. Name: `grc-flask-lab`
3. AMI: Amazon Linux 2023 or Ubuntu 22.04 LTS *(free-tier eligible)*
4. Instance type: `t2.micro` or `t3.micro` *(free-tier eligible)*
5. Key pair: `grc-flask-lab-key`
6. Network settings → Edit: Enable Auto-assign public IP, select `grc-flask-lab-sg`
7. Storage: 8 GB gp3 (default)
8. Click **Launch instance** and wait for `2/2 checks passed`
9. Copy the **Public IPv4 address**

> **Pain point #4:** All of these settings exist only in your head and the AWS Console. No record of which options you chose. Want to rebuild this in a new region? Start from scratch.

---

### Step 4: Connect via SSH

**macOS/Linux:**
```bash
# Amazon Linux AMI
ssh -i ~/.ssh/grc-flask-lab-key.pem ec2-user@<PUBLIC_IP>

# Ubuntu AMI
ssh -i ~/.ssh/grc-flask-lab-key.pem ubuntu@<PUBLIC_IP>
```

**Windows (PowerShell):**
```powershell
# Amazon Linux AMI
ssh -i "$env:USERPROFILE\.ssh\grc-flask-lab-key.pem" ec2-user@<PUBLIC_IP>

# Ubuntu AMI
ssh -i "$env:USERPROFILE\.ssh\grc-flask-lab-key.pem" ubuntu@<PUBLIC_IP>
```

**Windows (PuTTY):**
1. Open PuTTY → Host Name: `ec2-user@<PUBLIC_IP>` | Port: `22`
2. In the left panel go to: Connection → SSH → Auth → Credentials
3. Click Browse and select your `.ppk` file
4. Click **Open**

**Troubleshooting (all platforms):**

| Error | Likely Cause | Fix |
|---|---|---|
| `Permission denied (publickey)` | Wrong username or key path | Verify AMI type and key file location |
| `Connection timed out` | Security group blocks your IP | Check SG inbound rules for port 22 |
| `WARNING: UNPROTECTED PRIVATE KEY FILE` | Key permissions too open (Windows) | Re-run the `icacls` commands from Step 1 |
| `Host key verification failed` | EC2 IP reused from an old instance | Delete old entry from `~/.ssh/known_hosts` (macOS/Linux) or `C:\Users\<You>\.ssh\known_hosts` (Windows) |

---

### Step 5: Install Dependencies

Once connected via SSH, you're running commands on the Linux EC2 instance, these are the same regardless of what OS your local machine is:

**Amazon Linux 2023:**
```bash
sudo dnf update -y
sudo dnf install python3 python3-pip -y
python3 --version && pip3 --version
```

**Ubuntu 22.04:**
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install python3 python3-pip python3-venv -y
python3 --version && pip3 --version
```

---

### Step 6: Create the Flask Application

```bash
mkdir ~/flask-app && cd ~/flask-app
python3 -m venv venv
source venv/bin/activate
pip install flask
nano app.py
```

Paste the following into `app.py`:

```python
from flask import Flask, jsonify
from datetime import datetime

app = Flask(__name__)

@app.route('/')
def home():
    return '''
    <html>
        <head><title>GRC Engineering Club</title></head>
        <body style="font-family: Arial; max-width: 800px; margin: 50px auto; padding: 20px;">
            <h1>GRC Engineering Club</h1>
            <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0;">
                <h2>Flask on EC2 Lab</h2>
                <p>If you can see this page, you have successfully:</p>
                <ul>
                    <li>Provisioned an EC2 instance</li>
                    <li>Configured security groups</li>
                    <li>Installed Python and Flask</li>
                    <li>Deployed a web application</li>
                </ul>
            </div>
        </body>
    </html>
    '''

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'grc-flask-lab'
    })

@app.route('/api/controls')
def controls():
    return jsonify({
        'framework': 'NIST 800-53',
        'controls': [
            {'id': 'AC-2', 'name': 'Account Management', 'status': 'Implemented'},
            {'id': 'SC-7', 'name': 'Boundary Protection', 'status': 'Implemented'},
            {'id': 'AU-2', 'name': 'Audit Events', 'status': 'Partial'}
        ]
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
```

Save and exit: `Ctrl+X`, then `Y`, then `Enter`.

---

### Step 7: Run the Application

```bash
cd ~/flask-app
source venv/bin/activate
python app.py
```

Test in your browser (use your EC2 instance's Public IPv4):
```
http://<EC2_PUBLIC_IP>:5000
http://<EC2_PUBLIC_IP>:5000/health
http://<EC2_PUBLIC_IP>:5000/api/controls
```

**Test the API from your local machine:**

macOS/Linux:
```bash
curl http://<EC2_PUBLIC_IP>:5000/health
```

Windows (PowerShell):
```powershell
Invoke-WebRequest -Uri "http://<EC2_PUBLIC_IP>:5000/health" | Select-Object -ExpandProperty Content
```

> **Pain point #5:** The app runs in the foreground. Close the SSH session and the app dies. You have to either keep the terminal open or set up a background service — manually.

---

### Step 8: Run Flask as a Background Service

```bash
# Exit running Flask app (Ctrl+C), then:
sudo nano /etc/systemd/system/flask-app.service
```

Paste the following. If using Ubuntu, replace `ec2-user` with `ubuntu` on the three User/path lines:

```ini
[Unit]
Description=GRC Flask Application
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user/flask-app
Environment="PATH=/home/ec2-user/flask-app/venv/bin"
ExecStart=/home/ec2-user/flask-app/venv/bin/python app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable flask-app
sudo systemctl start flask-app
sudo systemctl status flask-app
```

Useful commands:
```bash
sudo systemctl stop flask-app       # Stop the service
sudo systemctl restart flask-app    # Restart after code changes
sudo journalctl -u flask-app -f     # View logs in real-time
```

---

### Step 9: Verify

1. **Browser:** Visit `http://<EC2_PUBLIC_IP>:5000`
2. **API test from your local terminal:**
   - macOS/Linux: `curl http://<EC2_PUBLIC_IP>:5000/health`
   - Windows PowerShell: `Invoke-WebRequest -Uri "http://<EC2_PUBLIC_IP>:5000/health" | Select-Object -ExpandProperty Content`
3. **Persistence test:** Close your SSH session, wait a minute, then verify the app is still accessible in the browser.

> **Pain point summary:** You just spent 20–30 minutes clicking through menus, making configuration decisions that live nowhere except the console, and troubleshooting issues that stem from manual error. Imagine doing this across 50 instances, 3 environments, or in a disaster recovery scenario. This is the problem Terraform solves.

---

## 4. Part 2: Cleanup

**Don't leave resources running.**

### Stop (preserves your work, pauses costs):
EC2 Dashboard → Instances → Select instance → **Instance state → Stop**

### Terminate (full removal):

1. **Terminate EC2 instance:** Instance state → Terminate
2. **Delete security group:** Security Groups → Select → Actions → Delete
3. **Delete key pair:** Key Pairs → Select → Actions → Delete
4. **Delete local key file:**

   macOS/Linux:
   ```bash
   rm ~/.ssh/grc-flask-lab-key.pem
   ```

   Windows (PowerShell):
   ```powershell
   Remove-Item "$env:USERPROFILE\.ssh\grc-flask-lab-key.pem"
   ```

> **Pain point #6:** Nothing automatically tells you what resources exist or reminds you to clean them up. It's easy to leave an instance running and forget about it until a bill arrives. With Terraform, `terraform destroy` removes *everything* defined in your configuration — no hunting through the console.

---

## 5. Part 3: Terraform Deployment

With Terraform, the entire deployment from Part 1 becomes a 2–3 minute operation that's repeatable, version-controlled, and auditable.

### Project Structure

```
terraform-flask-lab/
├── main.tf           # Core infrastructure: security group, key pair, EC2 instance
├── variables.tf      # Variable definitions with defaults
├── outputs.tf        # Auto-generated outputs (IP, SSH command, URL)
├── terraform.tfvars  # Your environment-specific values (region, key path)
├── userdata.sh       # Bootstraps Flask app automatically on instance launch
└── .gitignore        # Prevents committing state files and credentials
```

### Setup: Generate an SSH Key Pair

If you don't already have an SSH key pair:

**macOS/Linux:**
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
# Press Enter twice to skip a passphrase (or set one for extra security)
```

**Windows (PowerShell):**
```powershell
# Create the .ssh folder if it doesn't exist
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.ssh"

# Generate the key pair
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\id_rsa"
# Press Enter twice to skip a passphrase (or set one for extra security)
```

This creates two files: `id_rsa` (private — never share this) and `id_rsa.pub` (public — Terraform uploads this to AWS).

### Configure `terraform.tfvars`

**macOS/Linux:**
```hcl
aws_region      = "us-east-1"
project_name    = "grc-flask-lab"
environment     = "lab"
instance_type   = "t3.micro"
public_key_path = "~/.ssh/id_rsa.pub"
```

**Windows — use the full path with forward slashes:**
```hcl
aws_region      = "us-east-1"
project_name    = "grc-flask-lab"
environment     = "lab"
instance_type   = "t3.micro"
public_key_path = "C:/Users/YourUsername/.ssh/id_rsa.pub"
```

> **Windows note:** Terraform accepts forward slashes (`/`) in paths on Windows. Find your username by running `echo $env:USERNAME` in PowerShell.

### Deploy

The commands are identical on all platforms:

```bash
# Download required providers
terraform init

# Preview what will be created — review before applying
terraform plan

# Create all infrastructure
terraform apply

# View your outputs (IP, URL, SSH command)
terraform output
```

Terraform creates the security group, uploads your key pair, launches the EC2 instance, and runs the Flask setup script automatically — everything from Part 1, in one command.

### Connect After Deployment

Run `terraform output` and copy the `ssh_command` value.

**macOS/Linux:**
```bash
ssh -i ~/.ssh/id_rsa ec2-user@<auto-generated-ip>
```

**Windows (PowerShell):**
```powershell
ssh -i "$env:USERPROFILE\.ssh\id_rsa" ec2-user@<auto-generated-ip>
```

### Teardown

```bash
terraform destroy
```

Every resource Terraform created is removed. Nothing left behind.

---

## 6. Manual vs. Terraform — Side-by-Side Comparison

| Aspect | Manual (Console) | Terraform |
|---|---|---|
| **Time to deploy** | 20–30 minutes | 2–3 minutes after initial setup |
| **Repeatability** | Error-prone, relies on documentation and memory | Exact same result every time |
| **Audit trail** | Screenshots, notes, maybe a Confluence page | Git history of `.tf` files — every change tracked |
| **Cleanup** | Easy to miss resources; must hunt through console | `terraform destroy` removes everything |
| **Collaboration** | "It works on my console" | Code reviews and version control before changes go live |
| **Drift detection** | Someone edits a security group in the console — you may never know | `terraform plan` immediately shows the diff |
| **Disaster recovery** | Rebuild from documentation and memory | Re-run `terraform apply` in a new region |
| **Your IP changes** | Manually edit the SSH security group rule | Terraform fetches your current IP automatically at apply time |
| **Key permissions** | Manual `chmod`/`icacls` steps easy to forget or get wrong | Terraform handles key upload; local key is configured once |

### The GRC Perspective

Terraform doesn't just save time — it directly addresses compliance control families:

| NIST Control | How Terraform Helps |
|---|---|
| CM-2 (Baseline Configuration) | Your `.tf` files *are* the baseline |
| CM-3 (Configuration Change Control) | Git history + pull request approvals |
| CM-6 (Configuration Settings) | Codified, peer-reviewable settings |
| CM-8 (System Component Inventory) | `terraform state list` shows every resource |
| AU-6 (Audit Review) | Git commits record who changed what and when |
| SA-10 (Developer Config Management) | Infrastructure treated like application code |

---

## 7. Repository Structure

```
.
├── .gitignore        # Excludes state files, .terraform/, *.pem, credentials
├── README.md         # This file
├── main.tf           # Security group, key pair, EC2 instance definitions
├── variables.tf      # Input variable declarations
├── outputs.tf        # flask_url, ssh_command, instance_public_ip
└── terraform.tfvars  # Your values — region, key path, project name
```

> **Never commit:** `*.tfstate`, `.terraform/`, `*.pem`, or any file containing credentials. The `.gitignore` in this repo covers these, but always double-check before pushing.

---

## 8. GRC Control Mappings

Each step in this lab maps to real NIST 800-53 controls:

| Lab Component | Control | Control Name |
|---|---|---|
| MFA on AWS root account | IA-2(1) | Multi-Factor Authentication |
| SSH key pair | IA-2, IA-5 | Identification & Authentication, Authenticator Management |
| Security group (port 22 restricted) | AC-4, SC-7 | Information Flow Enforcement, Boundary Protection |
| EC2 instance tagging | CM-8 | System Component Inventory |
| Systemd service (auto-restart) | SI-2 | Flaw Remediation / Availability |
| Terraform Git history | CM-3, AU-6 | Configuration Change Control, Audit Review |
| Credentials outside project folder | IA-5, SC-12, SC-28 | Authenticator Mgmt, Key Mgmt, Protection at Rest |
| `.gitignore` for state/keys | SC-12, SC-28 | Cryptographic Key Management, Protection at Rest |

---

## Resources

- [Flask Documentation](https://flask.palletsprojects.com/)
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [NIST 800-53 Control Catalog](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [OpenSSH for Windows (Microsoft Docs)](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_overview)
- [Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/install)

---

*GRC Engineering Club — Bridging compliance and code.*
