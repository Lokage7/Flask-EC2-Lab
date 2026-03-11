# ============================================================
aws_region      = "us-east-1"           # &lt;-- CHANGE: Your preferred AWS region
project_name    = "FLask_EC2_Lab"       # &lt;-- OPTIONAL: Change if you want different naming
environment     = "lab"                 # &lt;-- OPTIONAL: Change for different environments
instance_type   = "t3.micro"            # &lt;-- Keep as-is for free tier
# IMPORTANT: This must point to YOUR public SSH key
public_key_path = "~/.ssh/id_rsa.pub"   # &lt;-- CHANGE: Path to YOUR public key
# If you don't have an SSH key yet, run this command first:
# ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
# Then use the path to the .pub file above
