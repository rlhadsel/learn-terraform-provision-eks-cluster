#! /bin/bash
sudo apt-get update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
sudo apt install unzip

# install aws cli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
/usr/local/bin/aws --version

curl -Lo /tmp/kubectl_v1-26-1 https://storage.googleapis.com/kubernetes-release/release/v1.26.1/bin/linux/amd64/kubectl
chmod +x /tmp/kubectl_v1-26-1
cp /tmp/kubectl_v1-26-1 /usr/local/bin/kubectl

curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html

<persist>true</persist>