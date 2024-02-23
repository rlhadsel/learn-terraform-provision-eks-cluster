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

# ClusterName="${cluster_name}"
# NodeGroupName="${nodegroup_name}"
# AWSAccountID=$(curl http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F\" '{print $4}')
# AWSRegion=$(curl http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')

# aws eks update-kubeconfig --region us-east-2 --name education-eks-7JJ27ijD

# curl -Lo /tmp/sc_reclaim_delete.yaml https://raw.githubusercontent.com/Esri/arcgis-enterprise-on-kubernetes-resources/main/StorageClasses/AmazonEKS/sc_reclaim_delete.yaml
# kubectl apply -f /tmp/sc_reclaim_delete.yaml

# kubectl get sc 

# cat > /tmp/aws-load-balancer-controller-service-account.yaml <<EOF
# apiVersion: v1
# kind: ServiceAccount
# metadata:
#   labels:
#     app.kubernetes.io/component: controller
#     app.kubernetes.io/name: aws-load-balancer-controller
#   name: aws-load-balancer-controller
#   namespace: kube-system
#   annotations:
#     eks.amazonaws.com/role-arn: arn:aws:iam::$AWSAccountID:role/AmazonEKSLoadBalancerControllerRole_$ClusterName
# EOF

# kubectl apply -f /tmp/aws-load-balancer-controller-service-account.yaml

echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html

<persist>true</persist>