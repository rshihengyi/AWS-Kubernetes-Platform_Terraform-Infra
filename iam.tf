data "aws_caller_identity" "current" {}

/* IAM role for Worker Nodes
    - allows the Pod Identity Agent to reach EKS Auth API on behalf of pods
*/
resource "aws_iam_role" "identity_agent_IAM_role" {
  name = "EKS-Worker-Node-IAM-role_For_Agent"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Sid    = ""
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "agent_pa" {
  role       = aws_iam_role.identity_agent_IAM_role.name
  policy_arn = aws_iam_policy.agent_permissions.arn
}

resource "aws_iam_policy" "agent_permissions" {
  name = "worker-node-permissions"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "eks-auth:AssumeRoleForPodIdentity",
        "Resource" : "*"
      }
    ]
  })
}

/* 
  IAM role for LB controller (Pod Identity IAM)

  Source: https://docs.aws.amazon.com/eks/latest/userguide/pod-id-association.html 
  Minimum Parameters: 
    - name:                 role name
    - assume_role_policy:   trust policy (who can wear the hat)

  Principal: Who can ask for aws credentials? - eks pods
*/

resource "aws_iam_role" "lb_controller" {
  name = "Load-Balancer-Controller-IAM-Role"
  assume_role_policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowEksAuthToAssumeRoleForPodIdentity",
        "Effect" : "Allow",

        "Action" : [
          "sts:AssumeRole",
          "sts:TagSession"
        ],

        "Principal" : {
          "Service" : "pods.eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"                  //Match namespace of service account
  service_account = "aws-load-balancer-controller" // This parameter is used if a pod needs to access aws resources. Defined in serviceaccount.yaml
  role_arn        = aws_iam_role.lb_controller.arn
}

// Retrieve policy from github
data "http" "lb_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "controller_permissions" {
  name   = "Controller-Permissions-List"
  policy = data.http.lb_controller_iam_policy.response_body
}

resource "aws_iam_role_policy_attachment" "controller_pa" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.controller_permissions.arn
}



/* IAM role for ExternalDNS (Pod Identity Agent IAM association)
    - Allow ExternalDNS to alter Route53 A record
*/

//Source: https://docs.aws.amazon.com/eks/latest/userguide/pod-id-association.html 
resource "aws_iam_role" "externalDNS_IAM_role" {
  name = "ExternalDNS-IAM-Role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowEksAuthToAssumeRoleForPodIdentity",
        "Effect" : "Allow",

        "Action" : [
          "sts:AssumeRole",
          "sts:TagSession"
        ],

        "Principal" : {
          "Service" : "pods.eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_eks_pod_identity_association" "externalDNS" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "external-dns"
  role_arn        = aws_iam_role.externalDNS_IAM_role.arn
}


resource "aws_iam_role_policy_attachment" "externalDNS_pa" {
  role       = aws_iam_role.externalDNS_IAM_role.name
  policy_arn = aws_iam_policy.externalDNS_permissions.arn
}

// ExternalDNS needs permission to write Route53 records -> 
// Official Documentation: https://kubernetes-sigs.github.io/external-dns/latest/docs/tutorials/aws/#iam-policy
resource "aws_iam_policy" "externalDNS_permissions" {
  name = "ExternalDNS-permissions"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "route53:ChangeResourceRecordSets",
            "route53:ListResourceRecordSets",
            "route53:ListTagsForResources",
            "route53:ListHostedZones"
            #"route53:*"
          ],
          "Resource" : [
            "arn:aws:route53:::hostedzone/*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "route53:ListHostedZones"
          ],
          "Resource" : [
            "*"
          ]
        }
      ]
    }
  )
}

/* IAM role to enable EBS CSI driver to create EBS volumes for pods
    - Allows the EBS CSI driver to create EBS volumes on behalf of pods
    - Source: https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html
*/

resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "EBS-CSi-Driver-Role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",

        "Action" : [
          "sts:AssumeRole",
          "sts:TagSession"
        ],

        "Principal" : {
          "Service" : "pods.eks.amazonaws.com"
        },
      }
    ]
  })
}

data "aws_iam_policy" "ebs_csi" {
  name = "AmazonEBSCSIDriverPolicyV2"
}

resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  cluster_name    = module.eks.cluster_name
  role_arn        = aws_iam_role.ebs_csi_driver_role.arn
  service_account = "ebs-csi-controller-sa"
  namespace       = "kube-system"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_pa" {
  role       = aws_iam_role.ebs_csi_driver_role.name
  policy_arn = data.aws_iam_policy.ebs_csi.arn
}


