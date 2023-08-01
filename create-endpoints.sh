#!/bin/bash
# Special Project
# Core function works but need to get menu and make OOP style (functions and such)
# Replace <cluster-name> with your actual EKS cluster name

# =============================================================================
# TODO: Implement Error Handeling
#       Implement ability to add extra security groups
# Error handling:
#                 See if Cluster was found
#                 See if VPC Information was obtainable
#                 Check if there are private subnets
#                 Check security groups returned
#                 Error handling for menu function
#                 Error handling for parsing arguments
#                 Error handling for adding VPCe
# =============================================================================c

# Set language to C to make sorting consistent among different environments.

export LANG="C"
export LC_ALL="C"
export AWS_PAGER=""


REQUIRED_UTILS=(
  jq
  aws
)

NAME=""
REGION=""
declare -A SUBNETS
declare -A SECURITY_GROUPS
declare -A EXTRA_ENDPOINTS
declare -A INTERFACES

# Retrieve the cluster information

collect_cluster() {
  CLUSTER_INFO=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION) || exit $?

  # Extract VPC ID, subnet IDs, and security group IDs
  VPC_ID=$(echo $CLUSTER_INFO | jq -r '.cluster.resourcesVpcConfig.vpcId')
  if [[ $VPC_ID != *"vpc-"* ]]; then
    exit "VPC ID was not found for cluster"
  fi
  # This will give us all of the subnets
  SUBNETS=($(echo $CLUSTER_INFO | jq -r '.cluster.resourcesVpcConfig.subnetIds[]' | tr '\n' ' '))
  private_subnets=()
  echo "Subnets: ${SUBNETS[@]}"
  echo "Selecting for private subnets only..."
  for s in "${SUBNETS[@]}"; do
    igw_count=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$s" --query "RouteTables[].Routes[]" | grep igw | wc -l)
    if [[ $igw_count -eq 0 ]]; then
      private_subnets+=("$s")
      #echo "subnet $s is a private subnet"
    #else 
      #echo "subnet $s is a public subnet"
    fi
  done

  if [[ ${#private_subnets[@]} -eq 0 ]]; then
    exit "No private subnets found"
  fi

  echo "Private Subnets: ${private_subnets[@]}"

  SECURITY_GROUPS=($(echo $CLUSTER_INFO | jq -r '.cluster.resourcesVpcConfig.securityGroupIds[]' | tr '\n' ' '))
  SECURITY_GROUPS+=($(echo $CLUSTER_INFO | jq -r '.cluster.resourcesVpcConfig.clusterSecurityGroupId'))
  # Print the VPC ID
  echo "VPC ID: $VPC_ID"
  # Print the security group IDs
  echo "Security Groups: ${SECURITY_GROUPS[@]}"
}

add_interfaces() {
  # We need to add a way to add the gateway endpoint for s3 if the customer does not want to add interfaces. 
  # inject core interfaces
  INTERFACES+=("com.amazonaws.REGION.ec2" "com.amazonaws.REGION.ecr.api" "com.amazonaws.REGION.ecr.dkr" "com.amazonaws.REGION.s3" "com.amazonaws.REGION.sts" "com.amazonaws.REGION.eks")

  # Extra interfaces
  # extra_interfaces=("com.amazonaws.REGION.elasticloadbalancing" "com.amazonaws.REGION.xray" "com.amazonaws.REGION.logs" "com.amazonaws.REGION.appmesh-envoy-management")
  INTERFACES=($(sed "s/REGION/${REGION}/g"<<<"${interfaces[@]}"))

  echo "Adding endpoints for private subnets only..."
  echo "Interfaces to add: ${interfaces[@]}"

  for i in "${INTERFACES[@]}"; do
      if aws ec2 create-vpc-endpoint \
          --region "$REGION" \
          --vpc-id "$VPC_ID" \
          --service-name "$i" \
          --vpc-endpoint-type Interface \
          --subnet-ids "${private_subnets[@]}" \
          --tag-specifications "ResourceType=vpc-endpoint,Tags=[{Key=service,Value=${i##*.}}]" \
          --security-group-id "${SECURITY_GROUPS[@]}"; then
          echo "Added VPC endpoint $i"
      else
          echo "Failed to add VPC endpoint $i"
      fi
  done
}

menu() {
    while [[ $# -gt 0 ]]; do
    key="$1"
    echo $key
    case $key in
        --help)
        cat << EOF
        Welcome to the Private VPC Endpoint tool for EKS 
        
        Pass the cluster name and region, and we will automatically add the nessesary endpoint to get your EKS cluster up and running (STS, EKS, ECR.API and ECR.DKR, and S3).

        USAGE:

        create-endpoint.sh --name <cluster-name> --region <region> --securityGroups <security-groups> --extraEndpoints <extra-endpoints>
        
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

EOF
        shift
        shift
        exit 0
        ;;
        -n|--name|-n=*|--name=*)
        NAME="$2"
        shift
        shift
        ;;
        -r|--region|-r=*|--region=*)
        REGION="$2"
        shift
        shift
        ;;
        --extraEndpoints)
        input=$2
        temp=("${input,,}")
        EXTRA_ENDPOINTS=($temp)
        shift
        shift
        ;;
        # Ability to add security groups that are not attached natively to the EKS cluster
        --securityGroups)
        input=$2
        temp=("${input,,}")
        SECURITY_GROUPS+=($temp)
        shift
        shift
        ;;
        -*|--*)
        # Handle unrecognized options or arguments here
        echo "Unknown option $key"
        exit 0
        ;;
        *)
        shift
        ;;
    esac
    done

    if [[ -z $NAME ]]; then
        exit "Please pass the cluster name"
    fi
    if [[ -z $REGION ]]; then
        exit "Please pass the cluster region"
    fi

    echo "NAME            = ${NAME}"
    echo "REGION          = ${REGION}"
    echo "EXTRA ENDPOINTS = ${EXTRA_ENDPOINTS[@]}"
    init
}

parse_arguments() {
    echo "Lets parse the Extra Endpoints"
    declare -A PARSE_INTERFACES
    PARSE_INTERFACES=([elb]="com.amazonaws.REGION.elasticloadbalancing" [xray]="com.amazonaws.REGION.xray" [logs]="com.amazonaws.REGION.logs" [appmesh]="com.amazonaws.REGION.appmesh-envoy-management" [elasticache]="com.amazonaws.REGION.elasticache" [ec-fips]="com.amazonaws.REGION.elasticache-fips" [autoscaling]="com.amazonaws.REGION.autoscaling")
    # echo
    # echo "Here are the available arguments: "
    # echo
    # for i in "${!INTERFACES[@]}"; do
    #     echo "${i} = ${INTERFACES[$i]}"
    # done
    echo "----------------------------------------" 
    echo "User Passed these: ${EXTRA_ENDPOINTS[@]}"
    echo "Which matches:"
    echo 
    for i in "${EXTRA_ENDPOINTS[@]}"; do
        local a="${PARSE_INTERFACES[$i]}"
        if [ -z "${PARSE_INTERFACES[$i]}" ]; then
            echo "$i did not match an available endpoint. Skipping this endpoint"
        else
            INTERFACES+=($a)
        fi
    done
}

check_required_utils() {
  for utils in ${REQUIRED_UTILS[@]}; do
    if ! command -v $utils &> /dev/null; then
      echo "Error: $utils is not installed"
      exit 1
    fi
  done
}

init() {
  check_required_utils
  collect_cluster
  add_interfaces
}

menu $@
parse_arguments

# ======================
exit 0