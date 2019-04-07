#Install kops
curl -Lo kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x ./kops
sudo mv ./kops /usr/local/bin/

#Install kubectl
curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

#Install awscli
sudo apt update
sudo apt install python-pip
pip --version
sudo pip install awscli

#Create I'm user and group and set permission
aws iam create-group --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name kops
aws iam create-user --user-name kops
aws iam add-user-to-group --user-name kops --group-name kops
aws iam create-access-key --user-name kops

# configure the aws client to use your new IAM user
aws configure           # Use your new access and secret key here
aws iam list-users      # you should see a list of all your IAM users here
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)

#Setup S3 bucket for storing cluster state
aws s3api create-bucket --bucket devstream-in-kube-state-store --region us-east-1
aws s3api put-bucket-versioning --bucket devstream-in-kube-state-store  --versioning-configuration Status=Enabled


#Setup Local environment variables
export NAME=devstream.k8s.local
export KOPS_STATE_STORE=s3://devstream-in-kube-state-store

#Create Cluster configuration
aws ec2 describe-availability-zones --region us-east-1
kops create cluster --zones us-east-1a,us-east-1b ${NAME}

#Setup kops secret
ssh-keygen -b 2049 -t rsa -f ~/.ssh/id_rsa
kops create secret --name devstream.k8s.local sshpublickey admin -i ~/.ssh/id_rsa.pub

#Customize cluster configuration
kops edit cluster ${NAME}
kops edit ig nodes --name ${NAME}
kops get ig --name ${NAME}

#Build the cluster
kops update cluster ${NAME} --yes

#Validate
kops validate cluster

#delete Cluster
#kops delete cluster --name ${NAME} --yes
