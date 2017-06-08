mkdir ~/.aws

cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = $aws_access_key
aws_secret_access_key = $aws_secret_key
EOF

cat > ~/.aws/config <<EOF
[default]
region = $aws_region
output = json
EOF
