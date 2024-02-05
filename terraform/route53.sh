#!/bin/bash

terraform init
terraform apply -auto-approve

# Congifure kubectl to work with created cluster
aws eks update-kubeconfig --region us-east-1 --name formapp-cluster

# # Initial password
echo "$(kubectl get -n argocd secret/argocd-initial-admin-secret -o=jsonpath='{.data.password}' | base64 -d)"

# Update record in aws hosted zone #
# get the dns name of elb
elb_dns_name=""
while [[ ! "$elb_dns_name" =~ \.elb\. ]]; do
  elb_dns_name=$(kubectl get ingress/nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  sleep 2
done


# create the record (json format)
cat > record.json <<EOF
{
    "Comment": "Update record",
    "Changes": [{
    "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "formapp.me",
                    "Type": "A",
                    "AliasTarget": {
                        "HostedZoneId": "Z041381537JPHY26OP7JJ",
                        "DNSName": "dualstack.$elb_dns_name",
                        "EvaluateTargetHealth": true
        }
    }}]
}
EOF

# update record in aws route 53
aws route53 change-resource-record-sets --hosted-zone-id Z041381537JPHY26OP7JJ --change-batch file://record.json