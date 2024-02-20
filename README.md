# Azure application gateway lab

This creates a resource group, a vnet with an Application gateway with 2 linux nginx webservers in a backendpool and a separate vnet with a client VM with an edited hosts file pointing testcert.com to the application gateway frontend. The client Windows VM has your public ip added to an NSG allowing RDP access. A keyvault is created and self-signed certificates are generated and put in the keyvault for the Application gateway to use for SSL termination and also installed on the client VM. This also creates a logic app that will delete the resource group in 24hrs. You'll be prompted for the resource group name, location where you want the resources created, your public ip and username and password to use for the VM's. From the client VM you can test reaching https://testcert.com and get responses from each webserver.

The topology will look like this:
![appgwlab](https://github.com/quiveringbacon/Azureappgatewaylab/assets/128983862/25a56877-5ec7-4e52-b08c-775888318567)


You can run Terraform right from the Azure cloud shell by cloning this git repository with "git clone https://github.com/quiveringbacon/Azureappgatewaylab.git ./terraform".

Then, "cd terraform" then, "terraform init" and finally "terraform apply -auto-approve" to deploy.
