# AWS EKS ADD VPCe


### Usage
Currently when creating a fully private cluster from the AWS EKS Management Console there is no way to quickly add VPC Endpoints that are required to run the EKS cluster. This script to allow customers to quickly be able to add required VPC Endpoints. 

### Example Output
Run this script where AWS CLI is authenticated to access cluster resources and create VPC Endpoints. 
```
create-endpoint.sh --help
        Welcome to the Private VPC Endpoint tool for EKS 
        
        Pass the cluster name and region to add the nessesary endpoint to get your EKS cluster up and running
        (STS, EKS, ECR.API and ECR.DKR, and S3).

        USAGE:

        create-endpoint.sh --name <cluster-name> \
        --region <region> \
        --securityGroups <security-groups> \
        --extraEndpoints <extra-endpoints>
        
        ---------------------------------------------------------------

        Options and Arguments to pass:

        --name ; Pass the name of the cluster | Required
        --region ; Pass the cluster region | Required
        --securityGroups ; Pass the security groups you want to add to the cluster.
        --extraEndpoints ; Accepts a space seperated string containing the additional endpoints to add to private subnets for the cluster
        Accepted values are:
                                "elb"=com.amazonaws.REGION.elasticloadbalancing 
                                "xray"=com.amazonaws.REGION.xray 
                                "logs"=com.amazonaws.REGION.logs 
                                "appmesh"=com.amazonaws.REGION.appmesh-envoy-management 
                                "elasticache"=com.amazonaws.REGION.elasticache 
                                "ec-fips"=com.amazonaws.REGION.elasticache-fips 
                                "autoscaling"=com.amazonaws.REGION.autoscaling
```


