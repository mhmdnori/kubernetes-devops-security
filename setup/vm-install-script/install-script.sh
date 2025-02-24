#!/bin/bash

echo ".........----------------#################._.-.-INSTALL-.-._.#################----------------........."
# تنظیمات پیشفرض ترمینال
PS1='\[\e[01;36m\]\u\[\e[01;37m\]@\[\e[01;33m\]\H\[\e[01;37m\]:\[\e[01;32m\]\w\[\e[01;37m\]\$\[\033[0;37m\] '
echo "PS1='\[\e[01;36m\]\u\[\e[01;37m\]@\[\e[01;33m\]\H\[\e[01;37m\]:\[\e[01;32m\]\w\[\e[01;37m\]\$\[\033[0;37m\] '" >> ~/.zshrc
sed -i '1s/^/force_color_prompt=yes\n/' ~/.zshrc
source ~/.zshrc

# به روزرسانی سیستم
apt-get autoremove -y
apt-get update -y
apt-get upgrade -y
systemctl daemon-reload

# نصب پیش نیازهای Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' > /etc/apt/sources.list.d/kubernetes.list

# نسخه های به روز شده
KUBE_VERSION=1.29.3
CONTAINERD_VERSION=1.7.13-1
apt-get update
apt-get install -y \
    containerd.io=${CONTAINERD_VERSION} \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    vim \
    build-essential \
    jq \
    python3-pip \
    kubelet=${KUBE_VERSION}-1.1 \
    kubectl=${KUBE_VERSION}-1.1 \
    kubernetes-cni=1.4.0-1 \
    kubeadm=${KUBE_VERSION}-1.1

pip3 install jc

# تنظیمات Docker
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "storage-driver": "overlay2"
}
EOF

systemctl daemon-reload
systemctl restart docker
systemctl enable docker
systemctl enable kubelet

# راه اندازی خوشه Kubernetes
echo ".........----------------#################._.-.-KUBERNETES-.-._.#################----------------........."
rm -rf /root/.kube/config
kubeadm reset -f

kubeadm init \
  --kubernetes-version=${KUBE_VERSION} \
  --pod-network-cidr=10.244.0.0/16 \
  --skip-token-print

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

# نصب شبکه overlay (Calico)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.1/manifests/calico.yaml

sleep 60

# حذف taint از node اصلی
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl taint nodes --all node.kubernetes.io/not-ready:NoSchedule-
kubectl get nodes -o wide

# نصب Java و Maven
echo ".........----------------#################._.-.-Java and MAVEN-.-._.#################----------------........."
apt-get install -y openjdk-17-jdk
update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java
java -version

apt-get install -y maven
mvn -v

# نصب Jenkins
echo ".........----------------#################._.-.-JENKINS-.-._.#################----------------........."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list

apt-get update
apt-get install -y jenkins

systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

usermod -aG docker jenkins
echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

echo ".........----------------#################._.-.-COMPLETED-.-._.#################----------------........."
