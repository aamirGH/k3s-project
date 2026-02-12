provider "aws" {
  region = "ap-south-1"
}

# ---------------- SECURITY GROUP ----------------
resource "aws_security_group" "k3s_sg" {
  name = "k3s-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 30007
    to_port     = 30007
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------- EC2 INSTANCE ----------------
resource "aws_instance" "k3s" {
  ami                         = "ami-02b8269d5e85954ef"
  instance_type               = "t3.medium"
  key_name                    = "key"
  subnet_id                   = "subnet-01d07762d5d1cd6cd"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.k3s_sg.id]

  provisioner "remote-exec" {
  inline = [
    "sudo apt update -y",
    "sudo apt install -y curl",

    # Install K3s with Public IP as TLS SAN
    "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=\"--tls-san ${self.public_ip}\" sh -",

    "sudo mkdir -p /home/ubuntu/.kube",
    "sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config",
    "sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config",
	"sudo chmod 700 /home/ubuntu/.kube/config",
	"sleep 20",
	
	# Prepare kubeconfig
    "sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/k3s.yaml",
    "sudo sed -i 's/127.0.0.1/${self.public_ip}/g' /home/ubuntu/k3s.yaml",
    "sudo base64 -w 0 /home/ubuntu/k3s.yaml > /home/ubuntu/k3s.yaml.b64"
   ]
  }


  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("key.pem")
    host        = self.public_ip
  }

  tags = {
    Name = "k3s-server"
  }
}


# ---------------- OUTPUT BASE64 ----------------
output "next_step_instruction" {
  value = "Take secret from file k3s.yaml.b64 and update on GitActions"
}

