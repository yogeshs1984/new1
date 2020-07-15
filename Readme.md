    
    
    https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/oms-linux
    
    
    https://docs.microsoft.com/en-us/azure/developer/terraform/create-vm-cluster-with-infrastructure

    
    https://www.pulumi.com/docs/reference/pkg/azure/storage/account/


    https://docs.microsoft.com/en-us/azure/developer/terraform/create-vm-scaleset-network-disks-hcl



    This is a great feature that every single Terraform team uses to collaborate, but it comes with one major gotcha: the backend configuration does not support variables or expressions of any sort. That is, the following will NOT work:

        # stage/frontend-app/main.tfterraform {
        backend "s3" {
            # Using variables does NOT work here!
            bucket = var.terraform_state_bucket
            key = var.terraform_state_key
            region = var.terraform_state_region
            encrypt = var.terraform_state_encrypt
            dynamodb_table = var.terraform_state_dynamodb_table
            }
        }