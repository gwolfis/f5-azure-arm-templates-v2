
# Deploying the BIG-IP VE in Azure - Example Auto Scale BIG-IP WAF (LTM + ASM) - VM Scale Set (Frontend via ALB) - PAYG Licensing

[![Releases](https://img.shields.io/github/release/f5networks/f5-azure-arm-templates-v2.svg)](https://github.com/f5networks/f5-azure-arm-templates-v2/releases)
[![Issues](https://img.shields.io/github/issues/f5networks/f5-azure-arm-templates-v2.svg)](https://github.com/f5networks/f5-azure-arm-templates-v2/issues)

## Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Important Configuration Notes](#important-configuration-notes)
- [Template Input Parameters](#template-input-parameters)
- [Template Outputs](#template-outputs)
- [Security](#security)
- [Installation](#installation)
- [Configuration Example](#configuration-example)
- [Getting Help](#getting-help)

## Introduction

This solution uses a parent template to launch several linked child templates (modules) to create a full example stack for the BIG-IP autoscale solution. The linked templates are located in the examples/modules directories in this repository. **F5 encourages you to clone this repository and modify these templates to fit your use case.** 

The modules below create the following resources:

- **Network**: This template creates Azure Virtual Networks, subnets, and Route Tables.
- **Application**: This template creates a generic example application for use when demonstrating live traffic through the BIG-IPs.
- **Disaggregation** *(DAG)*: This template creates resources required to get traffic to the BIG-IP, including Azure Network Security Groups, Public IP Addresses, internal/external Load Balancers, and accompanying resources such as load balancing rules, NAT rules, and probes.
- **Access**: This template creates an Azure Managed User Identity, KeyVault, and secret used to set the admin password on the BIG-IP instances.
- **BIG-IP**: This template creates the Microsoft Azure VM Scale Set with F5 BIG-IP Virtual Editions provisioned with Local Traffic Manager (LTM) and Application Security Manager (ASM). Traffic flows from the Azure load balancer to the BIG-IP VE instances and then to the application servers. The BIG-IP VE(s) are configured in single-NIC mode. Auto scaling means that as certain thresholds are reached, the number of BIG-IP VE instances automatically increases or decreases accordingly. The BIG-IP module template can be deployed separately from the example template provided here into an "existing" stack.

This solution leverages more traditional Auto Scale configuration management practices where each instance is created with an identical configuration as defined in the Scale Set's "model". Scale Set sizes are no longer restricted to the small limitations of the cluster. The BIG-IP's configuration, now defined in a single convenient YAML or JSON [F5 BIG-IP Runtime Init](https://github.com/F5Networks/f5-bigip-runtime-init) configuration file, leverages [F5 Automation Tool Chain](https://www.f5.com/pdf/products/automation-toolchain-overview.pdf) declarations which are easier to author, validate and maintain as code. For instance, if you need to change the configuration on the BIG-IPs in the deployment, you update the instance model by passing a new config file (which references the updated Automation Toolchain declarations) via template's bigIpRuntimeInitConfig input parameter. New instances will be deployed with the updated configurations.  

In most cases, it is especially expected that WAF or Application Service (as defined in AS3 declaration) will be customized, but if you use the default value from the example below for any of the service operations, the corresponding example declaration from the BIG-IP module folder will be used.

F5 has provided the following F5 BIG-IP Runtime Init configurations and example declarations for the supported Automation Toolchain components in the examples/autoscale/bigip-configurations folder:

- runtime-init-conf-bigiq.yaml: This configuration file installs packages and creates WAF-protected services for a BIG-IQ licensed deployment based on the Automation Toolchain declaration URLs listed above.
- runtime-init-conf-payg.yaml: This inline configuration file installs packages and creates WAF-protected services for a PAYG licensed deployment.
- Rapid_Deployment_Policy_13_1.xml: This ASM security policy is supported for BIG-IP 13.1 and later.

Notes: 
- The AS3 declaration example uses Service Discovery to populate the pool with the private IP addresses of application servers in a Virtual Machine Scale Set. The resourceGroup and subscriptionId field values are rendered from Azure instance metadata; the resourceId field value uses the value of the ***uniqueString*** input parameter that was provided at deployment time. Replace ***uniqueString*** in this AS3 configuration with the value you supply when creating the deployment. 
- If the application VMSS is located in a different resource group or subscription, substitute the actual values for those fields in the AS3 declaration. The managed identity assigned to the BIG-IP VE instance(s) must have read permissions on the VMSS resource.
- The Service Discovery configuration listed below targets a specific application VMSS ID to reduce the number of requests made to the Azure API endpoints. When choosing capacity for the BIG-IP VE and application VMSS, it is possible to exceed the API request limits. Consult the Azure resource manager [documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/request-limits-and-throttling) for more information.


Here is an example F5 BIG-IP Runtime Init configuration that uses the previously referenced Automation Toolchain declarations:

```yaml
---
bigip_ready_enabled: []
extension_packages:
  install_operations:
  - extensionHash: 15c1b919954a91b9ad1e469f49b7a0915b20de494b7a032da9eb258bbb7b6c49
    extensionType: do
    extensionVersion: 1.19.0
  - extensionHash: b33a96c84b77cff60249b7a53b6de29cc1e932d7d94de80cc77fb69e0b9a45a0
    extensionType: as3
    extensionVersion: 3.26.0
  - extensionHash: 9c617f5bb1bb0d08ec095ce568a6d5d2ef162e504cd183fe3540586200f9d950
    extensionType: fast
    extensionVersion: 1.7.0
  - extensionHash: b8c14a8b357f4dfcf59185b25a82f322ec98b17823be94cb3bd66f73c5e22781
    extensionType: ts
    extensionVersion: 1.16.0
extension_services:
  service_operations:
  - extensionType: do
    type: inline
    value:
      Common:
        class: Tenant
        dbvars:
          class: DbVariables
          provision.extramb: 500
          restjavad.useextramb: true
        myDns:
          class: DNS
          nameServers:
          - 8.8.8.8
        myNtp:
          class: NTP
          servers:
          - 0.pool.ntp.org
          timezone: UTC
        myProvisioning:
          asm: nominal
          class: Provision
          ltm: nominal
        mySystem:
          autoPhonehome: true
          class: System
          hostname: "{{HOST_NAME}}.local"
      async: true
      class: Device
      label: myBIG-IPdeclarationfordeclarativeonboarding
      schemaVersion: 1.0.0
  - extensionType: as3
      type: inline
      value:
        schemaVersion: 3.0.0
        action: deploy
        class: ADC
        remark: Autoscale
        label: Autoscale
        declaration:
          Tenant_1:
            class: Tenant
            Shared:
              class: Application
              template: shared
              shared_pool:
                class: Pool
                members:
                - addressDiscovery: azure
                  addressRealm: private            
                  resourceGroup: '{{{RESOURCE_GROUP_NAME}}}'
                  resourceId: uniqueString-app-vmss
                  resourceType: scaleSet
                  servicePort: 80
                  subscriptionId: '{{{SUBSCRIPTION_ID}}}'
                  updateInterval: 60
                  useManagedIdentity: true
                monitors:
                  - http
            HTTPS_Service:
              class: Application
              template: https
              WAFPolicy:
                class: WAF_Policy
                url: 'https://raw.githubusercontent.com/F5Networks/f5-azure-arm-templates-v2/master/examples/autoscale/bigip-configurations/Rapid_Depolyment_Policy_13_1.xml'
                ignoreChanges: false
                enforcementMode: blocking          
              serviceMain:
                class: Service_HTTPS
                virtualAddresses:
                  - 0.0.0.0
                policyWAF:
                  use: WAFPolicy
                pool: "/Tenant_1/Shared/shared_pool"
                serverTLS:
                  bigip: "/Common/clientssl"
                redirect80: false
            HTTP_Service:
              class: Application
              template: http 
              WAFPolicy:
                class: WAF_Policy
                url: 'https://raw.githubusercontent.com/F5Networks/f5-azure-arm-templates-v2/master/examples/autoscale/bigip-configurations/Rapid_Depolyment_Policy_13_1.xml'
                ignoreChanges: false
                enforcementMode: blocking           
              serviceMain:
                class: Service_HTTP
                virtualAddresses:
                  - 0.0.0.0
                policyWAF:
                  use: WAFPolicy
                pool: "/Tenant_1/Shared/shared_pool"
  - extensionType: ts
    type: inline
    value:
      Azure_Consumer:
        appInsightsResourceName: dd-app-*
        class: Telemetry_Consumer
        maxBatchIntervalMs: 5000
        maxBatchSize: 250
        trace: true
        type: Azure_Application_Insights
        useManagedIdentity: true
      Bigip_Poller:
        actions:
        - includeData: {}
          locations:
            system:
              cpu: true
              networkInterfaces:
                '1.0':
                  counters.bitsIn: true
        class: Telemetry_System_Poller
        interval: 60
      class: Telemetry
      controls:
        class: Controls
        debug: true
        logLevel: debug
post_onboard_enabled: []
pre_onboard_enabled: []
runtime_parameters:
- name: HOST_NAME
  type: metadata
  metadataProvider:
    environment: azure
    type: compute
    field: name
- name: RESOURCE_GROUP_NAME
  type: url
  value: http://169.254.169.254/metadata/instance/compute?api-version=2020-09-01
  query: resourceGroupName
  headers:
    - name: Metadata
      value: true
- name: SUBSCRIPTION_ID
  type: url
  value: http://169.254.169.254/metadata/instance/compute?api-version=2020-09-01
  query: subscriptionId
  headers:
    - name: Metadata
      value: true
```

And which you would reference in your parameter file:

```json
        "useAvailabilityZones": {
            "value": false
        },
        "bigIpRuntimeInitConfig": {
            "value": "https://raw.githubusercontent.com/myorg/mydeployment/0.0.1/bigip-configs/bigip-init-config.yaml"
        },
```

Or the same F5 BIG-IP Runtime Init configuration as json:

```json
{"bigip_ready_enabled":[],"extension_packages":{"install_operations":[{"extensionHash":"15c1b919954a91b9ad1e469f49b7a0915b20de494b7a032da9eb258bbb7b6c49","extensionType":"do","extensionVersion":"1.19.0"},{"extensionHash":"b33a96c84b77cff60249b7a53b6de29cc1e932d7d94de80cc77fb69e0b9a45a0","extensionType":"as3","extensionVersion":"3.26.0"},{"extensionHash":"9c617f5bb1bb0d08ec095ce568a6d5d2ef162e504cd183fe3540586200f9d950","extensionType":"fast","extensionVersion":"1.7.0"},{"extensionHash":"b8c14a8b357f4dfcf59185b25a82f322ec98b17823be94cb3bd66f73c5e22781","extensionType":"ts","extensionVersion":"1.16.0"}]},"extension_services":{"service_operations":[{"extensionType":"do","type":"inline","value":{"Common":{"class":"Tenant","dbVars":{"class":"DbVariables","restjavad.useextramb":true,"provision.extramb":500},"myDns":{"class":"DNS","nameServers":["168.63.129.16"]},"myNtp":{"class":"NTP","servers":["0.pool.ntp.org"],"timezone":"UTC"},"myProvisioning":{"asm":"nominal","class":"Provision","ltm":"nominal"},"mySystem":{"autoPhonehome":true,"class":"System","hostname":"{{HOST_NAME}}.local"}},"async":true,"class":"Device","label":"myBIG-IPdeclarationfordeclarativeonboarding","schemaVersion":"1.0.0"}},{"extensionType":"as3","type":"inline","value":{"schemaVersion":"3.0.0","class":"ADC","remark":"Autoscale","label":"Autoscale","Tenant_1":{"class":"Tenant","Shared":{"class":"Application","template":"shared","shared_pool":{"class":"Pool","members":[{"addressDiscovery":"azure","addressRealm":"private","resourceGroup":"{{{RESOURCE_GROUP_NAME}}}","resourceId":"uniqueString-app-vmss","resourceType":"scaleSet","servicePort":80,"subscriptionId":"{{{SUBSCRIPTION_ID}}}","updateInterval":60,"useManagedIdentity":true}],"monitors":["http"]}},"HTTPS_Service":{"class":"Application","template":"https","WAFPolicy":{"class":"WAF_Policy","url":"https://raw.githubusercontent.com/F5Networks/f5-azure-arm-templates-v2/master/examples/autoscale/bigip-configurations/Rapid_Depolyment_Policy_13_1.xml","ignoreChanges":false,"enforcementMode":"blocking"},"serviceMain":{"class":"Service_HTTPS","virtualAddresses":["0.0.0.0"],"policyWAF":{"use":"WAFPolicy"},"pool":"/Tenant_1/Shared/shared_pool","serverTLS":{"bigip":"/Common/clientssl"},"redirect80":false}},"HTTP_Service":{"class":"Application","template":"http","WAFPolicy":{"class":"WAF_Policy","url":"https://raw.githubusercontent.com/F5Networks/f5-azure-arm-templates-v2/master/examples/autoscale/bigip-configurations/Rapid_Depolyment_Policy_13_1.xml","ignoreChanges":false,"enforcementMode":"blocking"},"serviceMain":{"class":"Service_HTTP","virtualAddresses":["0.0.0.0"],"policyWAF":{"use":"WAFPolicy"},"pool":"/Tenant_1/Shared/shared_pool"}}}}},{"extensionType":"ts","type":"inline","value":{"Azure_Consumer":{"appInsightsResourceName":"app-*","class":"Telemetry_Consumer","maxBatchIntervalMs":5000,"maxBatchSize":250,"trace":true,"type":"Azure_Application_Insights","useManagedIdentity":true},"Bigip_Poller":{"actions":[{"includeData":{},"locations":{"system":{"cpu":true,"networkInterfaces":{"1.0":{"counters.bitsIn":true}}}}}],"class":"Telemetry_System_Poller","interval":60},"class":"Telemetry","controls":{"class":"Controls","debug":true,"logLevel":"debug"}}}]},"post_onboard_enabled":[],"pre_onboard_enabled":[],"runtime_parameters":[{"name":"HOST_NAME","type":"metadata","metadataProvider":{"environment":"azure","type":"compute","field":"name"}},{"name":"RESOURCE_GROUP_NAME","type":"url","value":"http://169.254.169.254/metadata/instance/compute?api-version=2020-09-01","query":"resourceGroupName","headers":[{"name":"Metadata","value":true}]},{"name":"SUBSCRIPTION_ID","type":"url","value":"http://169.254.169.254/metadata/instance/compute?api-version=2020-09-01","query":"subscriptionId","headers":[{"name":"Metadata","value":true}]}]}
```

which you would provide in your parameter file as a url or inline:

```json
        "useAvailabilityZones": {
            "value": false
        },
        "bigIpRuntimeInitConfig": {
            "value": "{\"bigip_ready_enabled\":[],\"extension_packages\":{\"install_operations\":[{\"extensionHash\":\"15c1b919954a91b9ad1e469f49b7a0915b20de494b7a032da9eb258bbb7b6c49\",\"extensionType\":\"do\",\"extensionVersion\":\"1.19.0\"},{\"extensionHash\":\"b33a96c84b77cff60249b7a53b6de29cc1e932d7d94de80cc77fb69e0b9a45a0\",\"extensionType\":\"as3\",\"extensionVersion\":\"3.26.0\"},{\"extensionHash\":\"9c617f5bb1bb0d08ec095ce568a6d5d2ef162e504cd183fe3540586200f9d950\",\"extensionType\":\"fast\",\"extensionVersion\":\"1.7.0\"},{\"extensionHash\":\"b8c14a8b357f4dfcf59185b25a82f322ec98b17823be94cb3bd66f73c5e22781\",\"extensionType\":\"ts\",\"extensionVersion\":\"1.16.0\"}]},\"extension_services\":{\"service_operations\":[{\"extensionType\":\"do\",\"type\":\"inline\",\"value\":{\"Common\":{\"class\":\"Tenant\",\"dbVars\":{\"class\":\"DbVariables\",\"restjavad.useextramb\":true,\"provision.extramb\":500},\"myDns\":{\"class\":\"DNS\",\"nameServers\":[\"168.63.129.16\"]},\"myNtp\":{\"class\":\"NTP\",\"servers\":[\"0.pool.ntp.org\"],\"timezone\":\"UTC\"},\"myProvisioning\":{\"asm\":\"nominal\",\"class\":\"Provision\",\"ltm\":\"nominal\"},\"mySystem\":{\"autoPhonehome\":true,\"class\":\"System\",\"hostname\":\"{{HOST_NAME}}.local\"}},\"async\":true,\"class\":\"Device\",\"label\":\"myBIG-IPdeclarationfordeclarativeonboarding\",\"schemaVersion\":\"1.0.0\"}},{\"extensionType\":\"as3\",\"type\":\"inline\",\"value\":{\"schemaVersion\":\"3.0.0\",\"class\":\"ADC\",\"remark\":\"Autoscale\",\"label\":\"Autoscale\",\"Tenant_1\":{\"class\":\"Tenant\",\"Shared\":{\"class\":\"Application\",\"template\":\"shared\",\"shared_pool\":{\"class\":\"Pool\",\"members\":[{\"addressDiscovery\":\"azure\",\"addressRealm\":\"private\",\"resourceGroup\":\"{{{RESOURCE_GROUP_NAME}}}\",\"resourceId\":\"uniqueString-app-vmss\",\"resourceType\":\"scaleSet\",\"servicePort\":80,\"subscriptionId\":\"{{{SUBSCRIPTION_ID}}}\",\"updateInterval\":60,\"useManagedIdentity\":true}],\"monitors\":[\"http\"]}},\"HTTPS_Service\":{\"class\":\"Application\",\"template\":\"https\",\"WAFPolicy\":{\"class\":\"WAF_Policy\",\"url\":\"https://raw.githubusercontent.com/F5Networks/f5-azure-arm-templates-v2/master/examples/autoscale/bigip-configurations/Rapid_Depolyment_Policy_13_1.xml\",\"ignoreChanges\":false,\"enforcementMode\":\"blocking\"},\"serviceMain\":{\"class\":\"Service_HTTPS\",\"virtualAddresses\":[\"0.0.0.0\"],\"policyWAF\":{\"use\":\"WAFPolicy\"},\"pool\":\"/Tenant_1/Shared/shared_pool\",\"serverTLS\":{\"bigip\":\"/Common/clientssl\"},\"redirect80\":false}},\"HTTP_Service\":{\"class\":\"Application\",\"template\":\"http\",\"WAFPolicy\":{\"class\":\"WAF_Policy\",\"url\":\"https://raw.githubusercontent.com/F5Networks/f5-azure-arm-templates-v2/master/examples/autoscale/bigip-configurations/Rapid_Depolyment_Policy_13_1.xml\",\"ignoreChanges\":false,\"enforcementMode\":\"blocking\"},\"serviceMain\":{\"class\":\"Service_HTTP\",\"virtualAddresses\":[\"0.0.0.0\"],\"policyWAF\":{\"use\":\"WAFPolicy\"},\"pool\":\"/Tenant_1/Shared/shared_pool\"}}}}},{\"extensionType\":\"ts\",\"type\":\"inline\",\"value\":{\"Azure_Consumer\":{\"appInsightsResourceName\":\"app-*\",\"class\":\"Telemetry_Consumer\",\"maxBatchIntervalMs\":5000,\"maxBatchSize\":250,\"trace\":true,\"type\":\"Azure_Application_Insights\",\"useManagedIdentity\":true},\"Bigip_Poller\":{\"actions\":[{\"includeData\":{},\"locations\":{\"system\":{\"cpu\":true,\"networkInterfaces\":{\"1.0\":{\"counters.bitsIn\":true}}}}}],\"class\":\"Telemetry_System_Poller\",\"interval\":60},\"class\":\"Telemetry\",\"controls\":{\"class\":\"Controls\",\"debug\":true,\"logLevel\":\"debug\"}}}]},\"post_onboard_enabled\":[],\"pre_onboard_enabled\":[],\"runtime_parameters\":[{\"name\":\"HOST_NAME\",\"type\":\"metadata\",\"metadataProvider\":{\"environment\":\"azure\",\"type\":\"compute\",\"field\":\"name\"}},{\"name\":\"RESOURCE_GROUP_NAME\",\"type\":\"url\",\"value\":\"http://169.254.169.254/metadata/instance/compute?api-version=2020-09-01\",\"query\":\"resourceGroupName\",\"headers\":[{\"name\":\"Metadata\",\"value\":true}]},{\"name\":\"SUBSCRIPTION_ID\",\"type\":\"url\",\"value\":\"http://169.254.169.254/metadata/instance/compute?api-version=2020-09-01\",\"query\":\"subscriptionId\",\"headers\":[{\"name\":\"Metadata\",\"value\":true}]}]}"
        },
```

Note: You must escape all double quotes when supplying the inline configuration as a template parameter.

For information on getting started using F5's ARM templates on GitHub, see [Microsoft Azure: Solutions 101](http://clouddocs.f5.com/cloud/public/v1/azure/Azure_solutions101.html).

## Prerequisites

 - This solution requires a valid F5 BIG-IP Runtime Init configuration URL or string in escaped JSON format. See above for links to example configuration, as well as an inline example.
 - This solution requires outbound Internet access for downloading the F5 BIG-IP Runtime Init and Automation Toolchain installation packages.
 - This solution makes requests to the Azure REST API to read and update Azure resources such as KeyVault secrets. For the solution to function correctly, you must ensure that the BIG-IP(s) can connect to the Azure REST API on port 443.
 - This solution makes requests  to the Azure REST API to read and update Azure resources, this has specifically been tested in Azure Commercial Cloud. Additional cloud environments such as Azure Government, Azure Germany and Azure China cloud have not yet been tested.
 - This template requires an SSH public key for access to the BIG-IP instances. 
 - If you provide a value for the newPassword template input parameter, the value is stored in an Azure KeyVault secret. The secret is read securely at deployment time and injected into the sample F5 Declarative Onboarding declaration. When deployment is complete, you can authenticate using the admin account using this password.
   -   **Disclaimer:** ***Accessing or logging into the instances themselves is for demonstration and debugging purposes only. All configuration changes should be applied by updating the model via the template instead.***   

## Important configuration notes

- If you have cloned this repository to an internally hosted location in order to modify the templates, you can use the templateBaseUrl and artifactLocation input parameters to specify the location of the modules.

- To facilitate this immutable deployment model, the BIG-IP leverages the F5 BIG-IP Runtime Init package.  The BIG-IP template requires a valid f5-bigip-runtime-init configuration file and execution command to be specified in the properties of the Azure Virtual Machine Scale Set resource. See <a href="https://github.com/F5Networks/f5-bigip-runtime-init">F5 BIG-IP Runtime Init</a> for more information.<br>

- In this solution, the BIG-IP VEs must have the [LTM](https://f5.com/products/big-ip/local-traffic-manager-ltm) and [ASM](https://f5.com/products/big-ip/application-security-manager-asm) modules enabled to provide advanced traffic management and web application security functionality. The provided Declarative Onboarding declaration describes how to provision these modules. This template uses BIG-IP **private** management address when license is requested via BIG-IQ.

- This template can send non-identifiable statistical information to F5 Networks to help us improve our templates. You can disable this functionality by setting the **autoPhonehome** system class property value to false in the F5 Declarative Onboarding declaration. See [Sending statistical information to F5](#sending-statistical-information-to-f5).

- F5 ARM templates now capture all deployment logs to the BIG-IP VE in **/var/log/cloud/azure**. Depending on which template you are using, this includes deployment logs (stdout/stderr) and more. Logs from Automation Toolchain components are located at **/var/log/restnoded/restnoded.log** on each BIG-IP instance.

- F5 ARM templates do not reconfigure existing Azure resources, such as network security groups. Depending on your configuration, you may need to configure these resources to allow the BIG-IP VE(s) to receive traffic for your application. Similarly, the DAG example template that deploys Azure Load Balancer(s) configures load balancing rules and probes on those resources to forward external traffic to the BIG-IP(s) on standard ports 443 and 80. F5 recommends cloning this repository and modifying the module templates to fit your use case.

- See the **[Configuration Example](#configuration-example)** section for a configuration diagram and description for this solution.


### Template Input Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| templateBaseUrl | Yes | The publicly accessible URL where the linked ARM templates are located. |
| artifactLocation | Yes | The directory, relative to the templateBaseUrl, where the modules folder is located. |
| uniqueString | Yes | A prefix that will be used to name template resources. Because some resources require globally unique names, we recommend using a unique value. |
| sshKey | Yes | Supply the public key that will be used for SSH authentication to the BIG-IP and application virtual machines. Note: This should be the public key as a string, typically starting with **---- BEGIN SSH2 PUBLIC KEY ----** and ending with **---- END SSH2 PUBLIC KEY ----**. |
| newPassword | No | The new password to be used for the admin user on the BIG-IP instances. This is required for creating the AZURE_PASSWORD secret referenced in the bigIpRuntimeInitConfig template parameter. If this value is left blank, the access module template is not deployed. |
| appContainerName | No | The name of a container to download and install which is used for the example application server. If this value is left blank, the application module template is not deployed. |
| restrictedSrcAddressMgmt | Yes | When creating management security group, this field restricts management access to a specific network or address. Enter an IP address or address range in CIDR notation, or asterisk for all sources. |
| image | Yes | 2 formats accepted. URN of the image to use in Azure marketplace or id of custom image. Example URN value: f5-networks:f5-big-ip-best:f5-bigip-virtual-edition-25m-best-hourly:15.1.201000. You can find the URNs of F5 marketplace images in the README for this template or by running the command: az vm image list --output yaml --publisher f5-networks --all. See https://clouddocs.f5.com/cloud/public/v1/azure/Azure_download.html for information on creating custom BIG-IP image. |
| bigIpRuntimeInitConfig | Yes | Supply a URL to the bigip-runtime-init configuration file in YAML or JSON format, or an escaped JSON string to use for f5-bigip-runtime-init configuration. |
| bigIpScalingMaxSize | Yes | Maximum number of BIG-IP instances (2-100) that can be created in the Auto Scale Group. |
| bigIpScalingMinSize | Yes | Minimum number of BIG-IP instances (1-99) you want available in the Auto Scale Group. |
| useAvailabilityZones | Yes | This deployment can deploy resources into Azure Availability Zones (if the region supports it).  If that is not desired the input should be set 'No'. If the region does not support availability zones the input should be set to No. |
| tagValues | Yes | Default key/value resource tags will be added to the resources in this deployment, if you would like the values to be unique adjust them as needed for each key. |

### Template Outputs

| Name | Description | Required Resource | Type |
| --- | --- | --- | --- |
| virtualNetworkId | Virtual Network resource ID | Network Template | string |
| appVmssName | Application Virtual Machine Scale Set name | Application Template | string |
| appPublicIps | Application Public IP Addresses | Application Template | array |
| appPrivateIp | Application Private IP Address | Application Template | string |
| appUsername | Application user name | Application Template | string |
| vmssId | Virtual Machine Scale Set resource ID | BIG-IP Template | string |
| bigipUsername | BIG-IP user name | BIG-IP Template | string |
| bigipPassword | BIG-IP password | BIG-IP Template | string |

## Security

This ARM template downloads helper code to configure the BIG-IP system:

- f5-bigip-runtime-init.gz.run: The self-extracting installer for the F5 BIG-IP Runtime Init RPM can be verified against a SHA256 checksum provided as a release asset on the F5 BIG-IP Runtime Init public Github repository, for example: https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/1.1.0/f5-bigip-runtime-init-1.1.0-1.gz.run.sha256.
- F5 BIG-IP Runtime Init: The self-extracting installer script extracts, verifies, and installs the F5 BIG-IP Runtime Init RPM package. Package files are signed by F5 and automatically verified using GPG.
- F5 Automation Toolchain components: F5 BIG-IP Runtime Init downloads, installs, and configures the F5 Automation Toolchain components. Although it is optional, F5 recommends adding the extensionHash field to each extension install operation in the configuration file. The presence of this field triggers verification of the downloaded component package checksum against the provided value. The checksum values are published as release assets on each extension's public Github repository, for example: https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.18.0/f5-appsvcs-3.18.0-4.noarch.rpm.sha256

The following configuration file will verify the Declarative Onboarding and Application Services extensions before configuring AS3 from a local file:

```yaml
runtime_parameters: []
extension_packages:
    install_operations:
        - extensionType: do
          extensionVersion: 1.17.0
          extensionHash: a359aa8aa14dc565146d4ccc413f169f1e8d02689559c5e4a652f91609a55fbb
        - extensionType: as3
          extensionVersion: 3.24.0
          extensionHash: df786fc755c5de6f3fcc47638caf3db4c071fcd9cf37855de78fd7e25e5117b4
extension_services:
    service_operations:
      - extensionType: as3
        type: url
        value: file:///examples/declarations/as3.json
```

More information about F5 BIG-IP Runtime Init and additional examples can be found in the [Github repository](https://github.com/F5Networks/f5-bigip-runtime-init/blob/main/README.md).

If you want to verify the integrity of the template itself, F5 provides checksums for all of our templates. For instructions and the checksums to compare against, see [checksums-for-f5-supported-cft-and-arm-templates-on-github](https://devcentral.f5.com/codeshare/checksums-for-f5-supported-cft-and-arm-templates-on-github-1014).

## BIG-IP versions

The following is a map that shows the available options for the template variable **image** as it corresponds to the BIG-IP version itself. Only the latest version of BIG-IP VE is posted in the Azure Marketplace. For older versions, see downloads.f5.com.

| Azure BIG-IP Image Version | BIG-IP Version |
| --- | --- |
| 15.1.201000 | 15.1.2.1 Build 0.0.10 |
| 14.1400000 | 14.1.3 Build 0.0.11 |
| latest | This will select the latest BIG-IP version available |

These templates have been tested and validated with the following versions of BIG-IP. 

| BIG-IP Version | Build Number |
| --- | --- |
| 15.1.2.1 | 0.0.10 |
| 14.1.4 | 0.0.11 |

## Supported instance types and hypervisors

- For a list of supported Azure instance types for this solution, see the [Azure instances for BIG-IP VE](http://clouddocs.f5.com/cloud/public/v1/azure/Azure_singleNIC.html#azure-instances-for-big-ip-ve).

- For a list of versions of the BIG-IP Virtual Edition (VE) and F5 licenses that are supported on specific hypervisors and Microsoft Azure, see [supported-hypervisor-matrix](https://support.f5.com/kb/en-us/products/big-ip_ltm/manuals/product/ve-supported-hypervisor-matrix.html).


## Installation

You have two options for deploying this solution:

- Using the Azure deploy buttons
- Using [CLI Tools](#azure-cli-20-script-example)

### Azure deploy buttons

Use the appropriate button below to deploy:

- **PAYG**: This allows you to use pay-as-you-go hourly billing.

  [![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FF5Networks%2Ff5-azure-arm-templates-v2%2Fv1.2.0.0%2Fexamples%2Fautoscale%2Fpayg%2Fazuredeploy.json)


### Programmatic deployments

As an alternative to deploying through the Azure Portal (GUI), each solution provides an example Azure CLI 2.0 command to deploy the ARM template. The following example deploys a PAYG-licensed, 1 NIC BIG-IP VE Azure Virtual Machine Scale Set.

#### Azure CLI (2.0) Script Example

```bash
RESOURCE_GROUP="myGroupName"
DEPLOY_PARAMS='{"templateBaseUrl":{"value":"https://cdn.f5.com/product/cloudsolutions/"},"artifactLocation":{"value":"f5-azure-arm-templates-v2/v1.2.0/examples/"},"uniqueString":{"value":"<value>"},"sshKey":{"value":"<value>"},"appContainer":{"value":"f5devcentral/f5-demo-app:1.0.1"},"restrictedSrcMgmtAddress":{"value":"<value>"},"runtimeConfig":{"value":"https://raw.githubusercontent.com/myorg/mydeployment/0.0.1/bigip-configs/bigip-init-config.yaml"},"newPassword":{"value":"<value>"},"useAvailabilityZones":{"value":<value>}}'
DEPLOY_PARAMS_FILE=${TMP_DIR}/deploy_params.json
echo ${DEPLOY_PARAMS} > ${DEPLOY_PARAMS_FILE}

az deployment group create --template-file ${TEMPLATE_FILE} -g ${RESOURCE_GROUP} -n ${RESOURCE_GROUP} --parameters @${DEPLOY_PARAMS_FILE}
```

## Validation

This section describes how to validate the template deployment, test the WAF service, and troubleshoot common problems.

### Validating the Deployment

To view the status of the example and module template deployments, navigate to Resource Groups->**your resource group name**->Deployments. You should see a series of deployments, including one each for the example template as well as the accessTemplate, appTemplate, networkTemplate, dagTemplate, bigipTemplate, and functionTemplate. The deployment status for each template deployment should be "Succeeded".  If any of the deployments are in a failed state, proceed to the Troubleshooting Steps section below.

### Testing the WAF Service

To test the WAF service, perform the following steps:
- Check the VM Scale Set instance health state; instance health is based on Azure's ability to connect to your application via the VM Scale Set's load balancer
  - Navigate to Resource Groups->**your resource group name**->Overview->**uniqueId-vmss**->Instances
  - The health state for each instance should be "Healthy". If the state is "Unhealthy", proceed to the troubleshooting steps section
- Obtain the IP address of the WAF service:
  - **Console**: Navigate to Resource Groups->**your resource group name**->Deployments->**your parent template deployment name**->Outputs->appPublicIps
  - **Azure CLI**: ```az deployment group show --name **your parent template deployment name** --resource-group **your resource group name** -o json --query properties.outputs.appPublicIps.value[0]```
- Verify the application is responding:
  - Paste the IP address in a browser: ```https://<IP Address from Output>```
  - Use curl: ```curl -so /dev/null -w '%{response_code}\n' https://<IP Address from Output>```
- Verify the WAF is configured to block illegal requests:
  - ```curl -sk -H "Content-Type: application/json; ls /usr/bin" https://<IP Address from Output>```
  - The response should include a message that the request was blocked, and a reference support ID

### Troubleshooting Steps

**Note**: These input parameter values are referenced throughout the troubleshooting steps. Use the value you supplied when deploying the template when running the following commands.
- uniqueId
- sshKey
- newPassword

There are generally two classes of issues:

1. Template deployment itself failed
2. Resource(s) within the template failed to deploy

To verify that all templates deployed successfully, follow the instructions under **Validating the Deployment** above to locate the failed deployment(s).

Click on the name of a failed deployment and then click Events. Click the link in the red banner at the top of the deployment overview for details about the failure cause. 

Additionally, if the template passed validation but individual template resources have failed to deploy, you can see more information by expanding Deployment Details, then clicking on the Operation details column for the failed resource. **When creating a Github issue for a template, please include as much information as possible from the failed Azure deployment/resource events.**

Common deployment failure causes include:
- Required fields were left empty or contained incorrect values (input type mismatch, prohibited characters, malformed JSON, etc.) causing template validation failure
- Insufficient permissions to create the deployment or resources created by a deployment (role assignments, etc.)
- Resource limitations (exceeded limit of IP addresses or compute resources, etc.)
- Azure service issues (these will usually surface as 503 internal server errors in the deployment status error message)

If all deployments completed successfully, wait a few minutes, then log in to the BIG-IP instance(s) via SSH to confirm BIG-IP deployment was successful (for example, if startup scripts completed as expected on the BIG-IPs). To verify BIG-IP deployment, perform the following steps:
- Obtain the IP address of the BIG-IP instance(s):
  - **Console**: Navigate to Resource Groups->**your resource group name**->Overview->**uniqueId-vmss**->Instances->**instance name**->Essentials->Public or Private IP address
  - **Azure CLI**: 
    - Public IPs: ```az vmss list-instance-public-ips --name **uniqueId-vmss** -g **your resource group name** -o json --query [].ipAddress```
    - Private IPs: ```az vmss nic list --vmss-name **uniqueId-vmss** -g **your resource group name** -o json --query [].ipConfigurations[].privateIpAddress```
- Login to each instance via SSH:
  - **SSH key authentication**: ```ssh azureuser@<IP Address from Output> -i <path to sshKey>```
  - **Password authentication**: ```ssh admin@<IP Address from Output>``` **newPassword** when prompted
- Check the logs:
  - /var/log/cloud/startup-script.log: This file contains events that happen prior to execution of f5-bigip-runtime-init. If the files required by the deployment fail to download, for example, you will see those events logged here.
  - /var/log/cloud/bigipRuntimeInit.log: This file contains events logged by the f5-bigip-runtime-init onboarding utility. If the configuration is invalid causing onboarding to fail, you will see those events logged here. If deployment is successful, you will see an event with the body "All operations completed successfully".
  - /var/log/restnoded/restnoded.log: This file contains events logged by the F5 Automation Toolchain components. If an Automation Toolchain declaration fails to deploy, you will see those events logged here.

If you are unable to login to the BIG-IP instance(s), you can navigate to Resource Groups->**your resource group name**->Overview->**uniqueId-vmss**->Instances->**instance name**->Support and Troubleshooting->Serial console for additional information from Azure.


## Validation

This section describes how to validate the template deployment, test the WAF service, and troubleshoot common problems.

### Validating the Deployment

To view the status of the example and module template deployments, navigate to Resource Groups->**your resource group name**->Deployments. You should see a series of deployments, including one each for the example template as well as the accessTemplate, appTemplate, networkTemplate, dagTemplate, bigipTemplate, and functionTemplate. The deployment status for each template deployment should be "Succeeded".  If any of the deployments are in a failed state, proceed to the Troubleshooting Steps section below.

### Testing the WAF Service

To test the WAF service, perform the following steps:
- Check the VM Scale Set instance health state; instance health is based on Azure's ability to connect to your application via the VM Scale Set's load balancer
  - Navigate to Resource Groups->**your resource group name**->Overview->**uniqueId-vmss**->Instances
  - The health state for each instance should be "Healthy". If the state is "Unhealthy", proceed to the troubleshooting steps section
- Obtain the IP address of the WAF service:
  - **Console**: Navigate to Resource Groups->**your resource group name**->Deployments->**your parent template deployment name**->Outputs->appPublicIps
  - **Azure CLI**: ```az deployment group show --name **your parent template deployment name** --resource-group **your resource group name** -o json --query properties.outputs.appPublicIps.value[0]```
- Verify the application is responding:
  - Paste the IP address in a browser: ```https://<IP Address from Output>```
  - Use curl: ```curl -so /dev/null -w '%{response_code}\n' https://<IP Address from Output>```
- Verify the WAF is configured to block illegal requests:
  - ```curl -sk -H "Content-Type: application/json; ls /usr/bin" https://<IP Address from Output>```
  - The response should include a message that the request was blocked, and a reference support ID

### Troubleshooting Steps

**Note**: These input parameter values are referenced throughout the troubleshooting steps. Use the value you supplied when deploying the template when running the following commands.
- uniqueId
- sshKey
- newPassword

There are generally two classes of issues:

1. Template deployment itself failed
2. Resource(s) within the template failed to deploy

To verify that all templates deployed successfully, follow the instructions under **Validating the Deployment** above to locate the failed deployment(s).

Click on the name of a failed deployment and then click Events. Click the link in the red banner at the top of the deployment overview for details about the failure cause. 

Additionally, if the template passed validation but individual template resources have failed to deploy, you can see more information by expanding Deployment Details, then clicking on the Operation details column for the failed resource. **When creating a Github issue for a template, please include as much information as possible from the failed Azure deployment/resource events.**

Common deployment failure causes include:
- Required fields were left empty or contained incorrect values (input type mismatch, prohibited characters, malformed JSON, etc.) causing template validation failure
- Insufficient permissions to create the deployment or resources created by a deployment (role assignments, etc.)
- Resource limitations (exceeded limit of IP addresses or compute resources, etc.)
- Azure service issues (these will usually surface as 503 internal server errors in the deployment status error message)

If all deployments completed successfully, wait a few minutes, then log in to the BIG-IP instance(s) via SSH to confirm BIG-IP deployment was successful (for example, if startup scripts completed as expected on the BIG-IPs). To verify BIG-IP deployment, perform the following steps:
- Obtain the IP address of the BIG-IP instance(s):
  - **Console**: Navigate to Resource Groups->**your resource group name**->Overview->**uniqueId-vmss**->Instances->**instance name**->Essentials->Public or Private IP address
  - **Azure CLI**: 
    - Public IPs: ```az vmss list-instance-public-ips --name **uniqueId-vmss** -g **your resource group name** -o json --query [].ipAddress```
    - Private IPs: ```az vmss nic list --vmss-name **uniqueId-vmss** -g **your resource group name** -o json --query [].ipConfigurations[].privateIpAddress```
- Login to each instance via SSH:
  - **SSH key authentication**: ```ssh azureuser@<IP Address from Output> -i <path to sshKey>```
  - **Password authentication**: ```ssh admin@<IP Address from Output>``` **newPassword** when prompted
- Check the logs:
  - /var/log/cloud/azure/install.log: This file contains events that happen prior to execution of f5-bigip-runtime-init. If the files required by the deployment fail to download, for example, you will see those events logged here.
  - /var/log/cloud/bigipRuntimeInit.log: This file contains events logged by the f5-bigip-runtime-init onboarding utility. If the configuration is invalid causing onboarding to fail, you will see those events logged here. If deployment is successful, you will see an event with the body "All operations completed successfully".
  - /var/log/restnoded/restnoded.log: This file contains events logged by the F5 Automation Toolchain components. If an Automation Toolchain declaration fails to deploy, you will see those events logged here.

If you are unable to login to the BIG-IP instance(s), you can navigate to Resource Groups->**your resource group name**->Overview->**uniqueId-vmss**->Instances->**instance name**->Support and Troubleshooting->Serial console for additional information from Azure.


## Configuration Example

The following is an example configuration diagram for this solution deployment. In this scenario, all access to the BIG-IP VE appliance is through an Azure Load Balancer. The Azure Load Balancer processes both management and data plane traffic into the BIG-IP VEs, which then distribute the traffic to web/application servers according to normal F5 patterns.

![Configuration Example](https://github.com/F5Networks/f5-azure-arm-templates-v2/blob/master/examples/autoscale/payg/diagram.png)

#### BIG-IP Lifecycle Management

As new BIG-IP versions are released, existing VM scale sets can be upgraded to use those new images. This section describes the process of upgrading and retaining the configuration.

#### To upgrade the BIG-IP VE Image

1. Update the VM Scale Set Model to the new BIG-IP version
    - From PowerShell: Use the PowerShell script in the **scripts** folder in this directory.
    - Using the Azure redeploy functionality: From the Resource Group where the ARM template was initially deployed, click the successful deployment and then select to redeploy the template. If necessary, re-select all the same variables, and **only change** the BIG-IP version to the latest.
2. Upgrade the Instances
    1. In Azure, navigate to the VM Scale Set instances pane and verify the *Latest model* does not say **Yes** (it should have a caution sign instead of the word Yes).
    2. Select either all instances at once or each instance one at a time (starting with instance ID 0 and working up).
    3. Click the **Upgrade** action button.

#### Configure Scale Event Notifications

**Note:** You can specify email addresses for notifications within the solution and they will be applied automatically. You can also manually configure them via the VM Scale Set configuration options available within the Azure Portal.

You can add notifications when scale up/down events happen, either in the form of email or webhooks. The following shows an example of adding an email address via the Azure Resources Explorer that receives an email from Azure whenever a scale up/down event occurs.

Log in to the [Azure Resource Explorer](https://resources.azure.com) and then navigate to the Auto Scale settings (**Subscriptions > Resource Groups >** *resource group where deployed* **> Providers > Microsoft.Insights > Autoscalesettings > autoscaleconfig**). At the top of the screen click Read/Write, and then from the Auto Scale settings, click **Edit**.  Replace the current **notifications** json key with the example below, making sure to update the email address(es). Select PUT and notifications will be sent to the email addresses listed.

```json
    "notifications": [
      {
        "operation": "Scale",
        "email": {
          "sendToSubscriptionAdministrator": false,
          "sendToSubscriptionCoAdministrators": false,
          "customEmails": [
            "email@f5.com"
          ]
        },
        "webhooks": null
      }
    ]
```


## Documentation

For more information on F5 solutions for Azure, including manual configuration procedures for some deployment scenarios, see the Azure section of [Public Cloud Docs](http://clouddocs.f5.com/cloud/public/v1/).


## Getting Help

Due to the heavy customization requirements of external cloud resources and BIG-IP configurations in these solutions, F5 does not provide technical support for deploying, customizing, or troubleshooting the templates themselves. However, the various underlying products and components used (for example: F5 BIG-IP Virtual Edition, F5 BIG-IP Runtime Init, Automation Toolchain extensions, and Cloud Failover Extension (CFE)) in the solutions located here are F5-supported and capable of being deployed with other orchestration tools. Read more about [Support Policies](https://www.f5.com/company/policies/support-policies). Problems found with the templates deployed as-is should be reported via a GitHub issue.


For help with authoring and support for custom CST2 templates, we recommend engaging F5 Professional Services (PS).


### Filing Issues

Use the **Issues** link on the GitHub menu bar in this repository for items such as enhancement or feature requests and bugs found when deploying the example templates as-is. Tell us as much as you can about what you found and how you found it.
