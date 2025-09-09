provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "cluster_role" {
  name = "cluster-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "eks.amazonaws.com"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role = aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_vpc" "cluster_vpc" {
  default = "true"
}

data "aws_subnets" "cluster_subnets" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.cluster_vpc.id]
  }
}

resource "aws_eks_cluster" "eks_cluster" {
  name = "eks-cluster"
  role_arn = aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids = data.aws_subnets.cluster_subnets.ids
    
  }

  depends_on = [ aws_iam_role_policy_attachment.eks_cluster_policy ]

}

resource "aws_iam_role" "node_group_role" {
  name = "node-group-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Principal": {
                "Service": [
                    "ec2.amazonaws.com"
                ]
            }
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_container_policy" {
  role = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "cluster_node_group" {
  node_group_name = "cluster_node_group"
  node_role_arn = aws_iam_role.node_group_role.arn
  cluster_name = aws_eks_cluster.eks_cluster.name
  subnet_ids      = data.aws_subnets.cluster_subnets.ids

    scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

    update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_policy
  ]
}
