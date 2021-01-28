
# Deploying the BIG-IP VE in Azure - Example Quickstart BIG-IP WAF (LTM + ASM) - Virtual Machine - BYOL Licensing

[![Releases](https://img.shields.io/github/release/f5networks/f5-azure-arm-templates-v2.svg)](https://github.com/f5networks/f5-azure-arm-templates-v2/releases)
[![Issues](https://img.shields.io/github/issues/f5networks/f5-azure-arm-templates-v2.svg)](https://github.com/f5networks/f5-azure-arm-templates-v2/issues)

## Contents

- [Deploying the BIG-IP VE in Azure - Example Quickstart BIG-IP WAF (LTM + ASM) - Virtual Machine - BYOL Licensing](#deploying-the-big-ip-ve-in-azure---example-quickstart-big-ip-waf-ltm--asm---virtual-machine---byol-licensing)
  - [Contents](#contents)
  - [Introduction](#introduction)
  - [Prerequisites](#prerequisites)
  - [Important configuration notes](#important-configuration-notes)
    - [Template Input Parameters](#template-input-parameters)
    - [Template Outputs](#template-outputs)
  - [Security](#security)
  - [BIG-IP versions](#big-ip-versions)
  - [Supported instance types and hypervisors](#supported-instance-types-and-hypervisors)
  - [Installation](#installation)
    - [Azure deploy buttons](#azure-deploy-buttons)
    - [Programmatic deployments](#programmatic-deployments)
      - [Azure CLI (2.0) Script Example](#azure-cli-20-script-example)
  - [Validation](#validation)
    - [Validating the Deployment](#validating-the-deployment)
    - [Testing the WAF Service](#testing-the-waf-service)
    - [Troubleshooting Steps](#troubleshooting-steps)
  - [Configuration Example](#configuration-example)
  - [Documentation](#documentation)
  - [Getting Help](#getting-help)
    - [Filing Issues](#filing-issues)

## Introduction

This solution uses a parent template to launch several linked child templates (modules) to create a full example stack for the BIG-IP quickstart solution. The linked templates are located in the examples/modules directories in this repository. **F5 encourages you to clone this repository and modify these templates to fit your use case.** 

The modules below create the following resources:

- **Network**: This template creates Azure Virtual Networks, subnets, and Route Tables.
- **Application**: This template creates a generic example application for use when demonstrating live traffic through the BIG-IP instance.
- **Disaggregation** *(DAG)*: This template creates resources required to get traffic to the BIG-IP, including Azure Network Security Groups, Public IP Addresses, internal/external Load Balancers, and accompanying resources such as load balancing rules, NAT rules, and probes.
- **BIG-IP**: This template creates the Microsoft Azure Virtual Machine with F5 BIG-IP Virtual Edition provisioned with Local Traffic Manager (LTM) and Application Security Manager (ASM). Traffic flows from the Azure external public IP address to the BIG-IP VE instance and then to the application servers. The BIG-IP VE is configured with up to 3 network interfaces. The BIG-IP module template can be deployed separately from the example template provided here into an "existing" stack.

F5 has provided the following F5 BIG-IP Runtime Init configurations for the supported Automation Toolchain components in the examples/quickstart/bigip-configurations folder:

- These configuration files install packages and create WAF-protected services for a BYOL licensed deployment.
  - runtime-init-conf-1nic-byol.yaml
  - runtime-init-conf-2nic-byol.yaml
  - runtime-init-conf-3nic-byol.yaml
- These configuration files install packages and create WAF-protected services for a PAYG licensed deployment.
  - runtime-init-conf-1nic-payg.yaml
  - runtime-init-conf-2nic-payg.yaml
  - runtime-init-conf-3nic-payg.yaml
- Rapid_Deployment_Policy_13_1.xml: This ASM security policy is supported for BIG-IP 13.1 and later.


Here is an example F5 BIG-IP Runtime Init configuration that uses the previously referenced Automation Toolchain declarations to deploy a 3NIC BIG-IP with PAYG licensing:

```yaml
---
extension_packages:
  install_operations:
    - extensionHash: 536eccb9dbf40aeabd31e64da8c5354b57d893286ddc6c075ecc9273fcca10a1
      extensionType: do
      extensionVersion: 1.16.0
    - extensionHash: de615341b91beaed59195dceefc122932580d517600afce1ba8d3770dfe42d28
      extensionType: as3
      extensionVersion: 3.23.0
extension_services:
  service_operations:
    - extensionType: do
      type: inline
      value:
        schemaVersion: 1.0.0
        class: Device
        async: true
        label: Standalone 3NIC BIG-IP declaration for Declarative Onboarding with BYOL license
        Common:
          class: Tenant
          dbVars:
            class: DbVariables
            config.allow.rfc3927: enable
            dhclient.mgmt: disable
          default:
            class: Route
            gw: 10.0.1.1
            network: default
          myNtp:
            class: NTP
            servers:
              - 0.pool.ntp.org
            timezone: UTC
          mySystem:
            autoPhonehome: true
            class: System
            hostname: '{{{ HOST_NAME }}}.local'
          myProvisioning:
            class: Provision
            ltm: nominal
            asm: nominal
          quickstart:
            class: User
            userType: regular
            partitionAccess:
              all-partitions:
                role: admin
            password: '{{{ HOST_NAME }}}'
            shell: bash
          external:
            class: VLAN
            tag: 4094
            mtu: 1500
            interfaces:
              - name: '1.1'
                tagged: true
          external-self:
            class: SelfIp
            address: '{{{ SELF_IP_EXTERNAL }}}'
            vlan: external
            allowService: none
            trafficGroup: traffic-group-local-only
          internal:
            class: VLAN
            tag: 4093
            mtu: 1500
            interfaces:
              - name: '1.2'
                tagged: true
          internal-self:
            class: SelfIp
            address: '{{{ SELF_IP_INTERNAL }}}'
            vlan: internal
            allowService: default
            trafficGroup: traffic-group-local-only
    - extensionType: as3
      type: inline
      value:
        action: deploy
        class: AS3
        declaration:
          Sample_http_01:
            A1:
              My_ASM_Policy:
                class: WAF_Policy
                ignoreChanges: true
                enforcementMode: blocking
                url: 'https://raw.githubusercontent.com/F5Networks/f5-azure-arm-templates-v2/master/examples/autoscale/bigip-configurations/Rapid_Depolyment_Policy_13_1.xml'
              class: Application
              serviceMain:
                class: Service_HTTP
                policyWAF:
                  use: My_ASM_Policy
                pool: webPool
                virtualAddresses:
                  - 0.0.0.0
                virtualPort: 80
              template: http
              webPool:
                class: Pool
                members:
                  - serverAddresses:
                      - 10.0.3.4
                    servicePort: 80
                monitors:
                  - http
            class: Tenant
          class: ADC
          label: Sample1
          remark: HTTPwithcustompersistence
          schemaVersion: 3.0.0
        persist: true
post_onboard_enabled:
  - name: create_metadata_route
    type: inline
    commands:
    - tmsh create sys management-route azureMetadata network 169.254.169.254/32 gateway
      10.0.0.1
    - tmsh save sys config
pre_onboard_enabled: []
runtime_parameters:
  - name: HOST_NAME
    type: metadata
    metadataProvider:
      environment: azure
      type: compute
      field: name
  - name: SELF_IP_EXTERNAL
    type: metadata
    metadataProvider:
      environment: azure
      type: network
      field: ipv4
      index: 1
  - name: SELF_IP_INTERNAL
    type: metadata
    metadataProvider:
      environment: azure
      type: network
      field: ipv4
      index: 2
```

And which you would reference in your parameter file:

```json
"useAvailabilityZones": {
    "value": false
},
"bigIpRuntimeInitConfig": {
    "value": "https://raw.githubusercontent.com/f5networks/f5-azure-arm-templates-v2/v0.0.2/examples/quickstart/bigip-configurations/runtime-init-conf-3nic-payg.yaml"
},
```

Or the same F5 BIG-IP Runtime Init configuration as json:

```json
{"extension_packages":{"install_operations":[{"extensionHash":"536eccb9dbf40aeabd31e64da8c5354b57d893286ddc6c075ecc9273fcca10a1","extensionType":"do","extensionVersion":"1.16.0"},{"extensionHash":"de615341b91beaed59195dceefc122932580d517600afce1ba8d3770dfe42d28","extensionType":"as3","extensionVersion":"3.23.0"}]},"extension_services":{"service_operations":[{"extensionType":"do","type":"inline","value":{"schemaVersion":"1.0.0","class":"Device","async":true,"label":"Standalone 3NIC BIG-IP declaration for Declarative Onboarding with PAYG license that uses custom DNS servers","Common":{"class":"Tenant","dbVars":{"class":"DbVariables","config.allow.rfc3927":"enable","dhclient.mgmt":"disable"},"default":{"class":"Route","gw":"10.0.1.1","network":"default"},"myDns":{"class":"DNS","nameServers":["8.8.8.8"]},"myNtp":{"class":"NTP","servers":["0.pool.ntp.org"],"timezone":"UTC"},"mySystem":{"autoPhonehome":true,"class":"System","hostname":"{{{HOST_NAME}}}.local"},"myProvisioning":{"class":"Provision","ltm":"nominal","asm":"nominal"},"quickstart":{"class":"User","userType":"regular","partitionAccess":{"all-partitions":{"role":"admin"}},"password":"{{{HOST_NAME}}}","shell":"bash"},"external":{"class":"VLAN","tag":4094,"mtu":1500,"interfaces":[{"name":"1.1","tagged":false}]},"external-self":{"class":"SelfIp","address":"{{{SELF_IP_EXTERNAL}}}","vlan":"external","allowService":"none","trafficGroup":"traffic-group-local-only"},"internal":{"class":"VLAN","tag":4093,"mtu":1500,"interfaces":[{"name":"1.2","tagged":false}]},"internal-self":{"class":"SelfIp","address":"{{{SELF_IP_INTERNAL}}}","vlan":"internal","allowService":"default","trafficGroup":"traffic-group-local-only"}}}},{"extensionType":"as3","type":"inline","value":{"action":"deploy","class":"AS3","declaration":{"Sample_http_01":{"A1":{"My_ASM_Policy":{"class":"WAF_Policy","ignoreChanges":true,"enforcementMode":"blocking","url":"https://raw.githubusercontent.com/F5Networks/f5-azure-arm-templates-v2/master/examples/autoscale/bigip-configurations/Rapid_Depolyment_Policy_13_1.xml"},"class":"Application","serviceMain":{"class":"Service_HTTP","policyWAF":{"use":"My_ASM_Policy"},"pool":"webPool","virtualAddresses":["10.0.1.10"],"virtualPort":80},"template":"http","webPool":{"class":"Pool","members":[{"serverAddresses":["10.0.3.4"],"servicePort":80}],"monitors":["http"]}},"class":"Tenant"},"class":"ADC","label":"Sample1","remark":"HTTPwithcustompersistence","schemaVersion":"3.0.0"},"persist":true}}]},"post_onboard_enabled":[{"name":"create_metadata_route","type":"inline","commands":["tmsh create sys management-route azureMetadata network 169.254.169.254/32 gateway 10.0.0.1","tmsh save sys config"]}],"pre_onboard_enabled":[],"runtime_parameters":[{"name":"HOST_NAME","type":"metadata","metadataProvider":{"environment":"azure","type":"compute","field":"name"}},{"name":"SELF_IP_EXTERNAL","type":"metadata","metadataProvider":{"environment":"azure","type":"network","field":"ipv4","index":1}},{"name":"SELF_IP_INTERNAL","type":"metadata","metadataProvider":{"environment":"azure","type":"network","field":"ipv4","index":2}}]}
```

which you would provide in your parameter file as a url or inline:

```json
        "useAvailabilityZones": {
            "value": false
        },
        "bigIpRuntimeInitConfig": {
            "value": "{\"extension_packages\":{\"install_operations\":[{\"extensionHash\":\"536eccb9dbf40aeabd31e64da8c5354b57d893286ddc6c075ecc9273fcca10a1\",\"extensionType\":\"do\",\"extensionVersion\":\"1.16.0\"},{\"extensionHash\":\"de615341b91beaed59195dceefc122932580d517600afce1ba8d3770dfe42d28\",\"extensionType\":\"as3\",\"extensionVersion\":\"3.23.0\"}]},\"extension_services\":{\"service_operations\":[{\"extensionType\":\"do\",\"type\":\"inline\",\"value\":{\"schemaVersion\":\"1.0.0\",\"class\":\"Device\",\"async\":true,\"label\":\"Standalone 3NIC BIG-IP declaration for Declarative Onboarding with PAYG license that uses custom DNS servers\",\"Common\":{\"class\":\"Tenant\",\"dbVars\":{\"class\":\"DbVariables\",\"config.allow.rfc3927\":\"enable\",\"dhclient.mgmt\":\"disable\"},\"default\":{\"class\":\"Route\",\"gw\":\"10.0.1.1\",\"network\":\"default\"},\"myDns\":{\"class\":\"DNS\",\"nameServers\":[\"8.8.8.8\"]},\"myNtp\":{\"class\":\"NTP\",\"servers\":[\"0.pool.ntp.org\"],\"timezone\":\"UTC\"},\"mySystem\":{\"autoPhonehome\":true,\"class\":\"System\",\"hostname\":\"{{{HOST_NAME}}}.local\"},\"myProvisioning\":{\"class\":\"Provision\",\"ltm\":\"nominal\",\"asm\":\"nominal\"},\"quickstart\":{\"class\":\"User\",\"userType\":\"regular\",\"partitionAccess\":{\"all-partitions\":{\"role\":\"admin\"}},\"password\":\"{{{HOST_NAME}}}\",\"shell\":\"bash\"},\"external\":{\"class\":\"VLAN\",\"tag\":4094,\"mtu\":1500,\"interfaces\":[{\"name\":\"1.1\",\"tagged\":false}]},\"external-self\":{\"class\":\"SelfIp\",\"address\":\"{{{SELF_IP_EXTERNAL}}}\",\"vlan\":\"external\",\"allowService\":\"none\",\"trafficGroup\":\"traffic-group-local-only\"},\"internal\":{\"class\":\"VLAN\",\"tag\":4093,\"mtu\":1500,\"interfaces\":[{\"name\":\"1.2\",\"tagged\":false}]},\"internal-self\":{\"class\":\"SelfIp\",\"address\":\"{{{SELF_IP_INTERNAL}}}\",\"vlan\":\"internal\",\"allowService\":\"default\",\"trafficGroup\":\"traffic-group-local-only\"}}}},{\"extensionType\":\"as3\",\"type\":\"inline\",\"value\":{\"action\":\"deploy\",\"class\":\"AS3\",\"declaration\":{\"Sample_http_01\":{\"A1\":{\"My_ASM_Policy\":{\"class\":\"WAF_Policy\",\"ignoreChanges\":true,\"enforcementMode\":\"blocking\",\"url\":\"https://raw.githubusercontent.com/F5Networks/f5-azure-arm-templates-v2/master/examples/autoscale/bigip-configurations/Rapid_Depolyment_Policy_13_1.xml\"},\"class\":\"Application\",\"serviceMain\":{\"class\":\"Service_HTTP\",\"policyWAF\":{\"use\":\"My_ASM_Policy\"},\"pool\":\"webPool\",\"virtualAddresses\":[\"10.0.1.10\"],\"virtualPort\":80},\"template\":\"http\",\"webPool\":{\"class\":\"Pool\",\"members\":[{\"serverAddresses\":[\"10.0.3.4\"],\"servicePort\":80}],\"monitors\":[\"http\"]}},\"class\":\"Tenant\"},\"class\":\"ADC\",\"label\":\"Sample1\",\"remark\":\"HTTPwithcustompersistence\",\"schemaVersion\":\"3.0.0\"},\"persist\":true}}]},\"post_onboard_enabled\":[{\"name\":\"create_metadata_route\",\"type\":\"inline\",\"commands\":[\"tmsh create sys management-route azureMetadata network 169.254.169.254/32 gateway 10.0.0.1\",\"tmsh save sys config\"]}],\"pre_onboard_enabled\":[],\"runtime_parameters\":[{\"name\":\"HOST_NAME\",\"type\":\"metadata\",\"metadataProvider\":{\"environment\":\"azure\",\"type\":\"compute\",\"field\":\"name\"}},{\"name\":\"SELF_IP_EXTERNAL\",\"type\":\"metadata\",\"metadataProvider\":{\"environment\":\"azure\",\"type\":\"network\",\"field\":\"ipv4\",\"index\":1}},{\"name\":\"SELF_IP_INTERNAL\",\"type\":\"metadata\",\"metadataProvider\":{\"environment\":\"azure\",\"type\":\"network\",\"field\":\"ipv4\",\"index\":2}}]}"
        },
```

You must escape all double quotes when supplying the inline configuration as a template parameter.

**Note**: To deploy the example above using a BYOL-licensed BIG-IP instance, make the following changes:
- Change the value of the image template parameter to a BYOL Azure Marketplace offer URN; for example: 
  ```json 
  "image":{ 
    "value": "f5-networks:f5-big-ip-byol:f5-big-all-2slot-byol:15.1.200000" 
  }
  ```
- Add a license class to the F5 BIG-IP Runtime Config declaration, where the value of regKey is the F5 license registration key:
  ```yaml
  myLicense:
    class: License
    licenseType: regKey
    regKey: AAAAA-BBBBB-CCCCC-DDDDD-EEEEEEE
  ``` 
  ```json
  "myLicense":{"class":"License","licenseType":"regKey","regKey":"AAAAA-BBBBB-CCCCC-DDDDD-EEEEEEE"}
  ```
- Change the value of the bigIpRuntimeInitConfig template parameter to the updated declaration:
  ```json
  "bigIpRuntimeInitConfig": {
      "value": "https://raw.githubusercontent.com/f5networks/f5-azure-arm-templates-v2/v0.0.2/examples/quickstart/bigip-configurations/runtime-init-conf-3nic-byol.yaml"
  }
  ```

For information on getting started using F5's ARM templates on GitHub, see [Microsoft Azure: Solutions 101](http://clouddocs.f5.com/cloud/public/v1/azure/Azure_solutions101.html).

## Prerequisites

 - This solution requires a valid F5 BIG-IP Runtime Init configuration URL or string in escaped JSON format. See above for links to example configuration, as well as an inline example.
 - This solution requires outbound Internet access for downloading the F5 BIG-IP Runtime Init and Automation Toolchain installation packages.
 - This solution makes requests to the Azure REST API to read and update Azure resources such as KeyVault secrets. For the solution to function correctly, you must ensure that the BIG-IP(s) can connect to the Azure REST API on port 443.
 - This solution makes requests  to the Azure REST API to read and update Azure resources, this has specifically been tested in Azure Commercial Cloud. Additional cloud environments such as Azure Government, Azure Germany and Azure China cloud have not yet been tested.
 - This solution requires an SSH public key for access to the BIG-IP instances.
 - This solution requires you to accept any Azure Marketplace "License/Terms and Conditions" for the image used to deploy the BIG-IP instance.
   - PAYG example: ```az vm image terms accept --urn f5-networks:f5-big-ip-best:f5-bigip-virtual-edition-25m-best-hourly-po-f5:15.1.200000```
   - For more information, see Azure [documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/cli-ps-findimage#deploy-an-image-with-marketplace-terms).

## Important configuration notes

- If you have cloned this repository to an internally hosted location in order to modify the templates, you can use the templateBaseUrl and artifactLocation input parameters to specify the location of the modules.

- To facilitate deployment, the BIG-IP leverages the F5 BIG-IP Runtime Init package.  The BIG-IP template requires a valid f5-bigip-runtime-init configuration file and execution command to be specified in the properties of the Azure Virtual Machine resource. See <a href="https://github.com/F5Networks/f5-bigip-runtime-init">F5 BIG-IP Runtime Init</a> for more information.<br>

- In the F5 BIG-IP Runtime Init configuration examples referenced above, a user with the username **quickstart** and a **temporary** password set to value of the Azure virtual machine name is configured on the BIG-IP VE instance. **IMPORTANT**: You should change this temporary password immediately following deployment. Alternately, you may remove the quickstart user class from the configuration prior to deployment to prevent this user account from being created.

- When specifying values for the instanceType and numNics parameters, ensure that the instance type you select is appropriate for the deployment scenario. See [Azure Virtual Machine Instance Types](https://docs.microsoft.com/en-us/azure/virtual-machines/dv2-dsv2-series) for more information.

- By default, this template creates 3 secondary private service IP configurations on the first non-management network interface (NIC1) if creating 2 or more NICs, and 1 secondary private service IP configuration on the second non-management interface (NIC2) if creating 3 NICs. When specifying a value of 1 for the numNics parameter (single NIC deployment), all private and public service (VIP) IP addresses will be assigned to the **secondary** IP configurations on NIC0. The NIC0 primary IP configuration is reserved for management traffic.

- When specifying a value for the numberPublicExternalIPAddresses with a 2 or 3 NIC deployment, the first public IP address will be assigned to the **primary** (self) IP configuration on NIC1. Therefore, when specifying a value of 4 for numberPublicExternalIPAddresses, 3 public service IP addresses will be created and assigned to the **secondary** IP configurations on NIC1. **Note**: The virtual server destination address(es) used in your AS3 declaration should reference the private service IP addresses configured on these secondary IP configurations.

- If you are deploying the solution into an Azure region that supports Availability Zones, you can specify True for the useAvailabilityZones parameter. See [Azure Availability Zones](https://docs.microsoft.com/en-us/azure/availability-zones/az-region#azure-regions-with-availability-zones) for a list of regions that support Availability Zones.

- In this solution, the BIG-IP VEs have the [LTM](https://f5.com/products/big-ip/local-traffic-manager-ltm) and [ASM](https://f5.com/products/big-ip/application-security-manager-asm) modules enabled to provide advanced traffic management and web application security functionality. The provided F5 BIG-IP Runtime Init declaration examples describe how to provision these modules.

- This template can send non-identifiable statistical information to F5 Networks to help us improve our templates. You can disable this functionality by setting the **autoPhonehome** system class property value to false in the F5 Declarative Onboarding declaration. See [Sending statistical information to F5](#sending-statistical-information-to-f5).

- F5 ARM templates now capture all deployment logs to the BIG-IP VE in **/var/log/cloud/**. Logs from Automation Toolchain components are located at **/var/log/restnoded/restnoded.log** on each BIG-IP instance. See the **[Troubleshooting Steps](#troubleshooting-steps)** section for detailed information on logging.

- F5 ARM templates do not reconfigure existing Azure resources, such as network security groups. Depending on your configuration, you may need to configure these resources to allow the BIG-IP VE instance to receive traffic for your application. Similarly, the DAG example template that deploys Azure Load Balancer(s) configures load balancing rules and probes on those resources to forward external traffic to the BIG-IP(s) on standard ports 443 and 80. F5 recommends cloning this repository and modifying the module templates to fit your use case.

- See the **[Configuration Example](#configuration-example)** section for a configuration diagram and description for this solution.


### Template Input Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| templateBaseUrl | Yes | The publicly accessible URL where the linked ARM templates are located. |
| artifactLocation | Yes | The directory, relative to the templateBaseUrl, where the modules folder is located. |
| uniqueString | Yes | A prefix that will be used to name template resources. Because some resources require globally unique names, we recommend using a unique value. |
| sshKey | Yes | Supply the public key that will be used for SSH authentication to the BIG-IP and application virtual machines. Note: This should be the public key as a string, typically starting with **---- BEGIN SSH2 PUBLIC KEY ----** and ending with **---- END SSH2 PUBLIC KEY ----**. |
| appContainerName | No | The name of a container to download and install which is used for the example application server(s). If this value is left blank, the application module template is not deployed. |
| numNics | Yes | Enter valid number of network interfaces (1-3) to create on the BIG-IP VE instance. |
| usePublicMgmtAddress | Yes | Enter true to configure management interface with public IP address. In most production environments this would be set to false. |
| numberPublicExternalIPAddresses | Yes | Enter valid number of external public IP addresses (1-4) to create on the external interface of the BIG-IP VE instance. If deploying with a single network interface, these public IP addresses will be associated with the management network interface. |
| restrictedSrcAddressMgmt | Yes | When creating management security group, this field restricts management access to a specific network or address. Enter an IP address or address range in CIDR notation, or asterisk for all sources. |
| bigIpRuntimeInitConfig | Yes | Supply a URL to the bigip-runtime-init configuration file in YAML or JSON format, or an escaped JSON string to use for f5-bigip-runtime-init configuration. |
| useAvailabilityZones | Yes | This deployment can deploy resources into Azure Availability Zones (if the region supports it).  If that is not desired the input should be set 'No'. If the region does not support availability zones the input should be set to No. |
| tagValues | Yes | Default key/value resource tags will be added to the resources in this deployment, if you would like the values to be unique adjust them as needed for each key. |

### Template Outputs

| Name | Description | Required Resource | Type |
| --- | --- | --- | --- |
| virtualNetworkId | Virtual Network resource ID | Network Template | string |
| mgmtPublicIp | Management Public IP Address | BIG-IP Template | string |
| mgmtPrivateIp | Management Private IP Address | BIG-IP Template | string |
| mgmtPublicUrl | Management Public IP Address | BIG-IP Template | string |
| mgmtPrivateUrl | Management Private IP Address | BIG-IP Template | string |
| appVmName | Application Virtual Machine name | Application Template | string |
| appPublicIps | Application Public IP Addresses | Application Template | array |
| appPrivateIp | Application Private IP Address | Application Template | string |
| vip1PrivateIp | Service (VIP) Private IP Address | Application Template | string |
| vip1PublicIp | Service (VIP) Public IP Address | Application Template | string |
| vip1PublicIPDns | Service (VIP) Public DNS | Application Template | string |
| vip1PrivateUrlHttp | Service (VIP) Private HTTP URL | Application Template | string |
| vip1PublicUrlHttp | Service (VIP) Public HTTP URL | Application Template | string |
| vip1PrivateUrlHttps | Service (VIP) Private HTTPS URL | Application Template | string |
| vip1PublicUrlHttps | Service (VIP) Public HTTPS URL | Application Template | string |
| vip2PrivateIp | Service (VIP) Private IP Address | Application Template | string |
| vip2PublicIp | Service (VIP) Public IP Address | Application Template | string |
| vip2PublicIPDns | Service (VIP) Public DNS | Application Template | string |
| vip2PrivateUrlHttp | Service (VIP) Private HTTP URL | Application Template | string |
| vip2PublicUrlHttp | Service (VIP) Public HTTP URL | Application Template | string |
| vip2PrivateUrlHttps | Service (VIP) Private HTTPS URL | Application Template | string |
| vip2PublicUrlHttps | Service (VIP) Public HTTPS URL | Application Template | string |
| appUsername | Application user name | Application Template | string |
| vmId | Virtual Machine resource ID | BIG-IP Template | string |
| bigipUsername | BIG-IP user name | BIG-IP Template | string |

## Security

This ARM template downloads helper code to configure the BIG-IP system:

- f5-bigip-runtime-init.gz.run: The self-extracting installer for the F5 BIG-IP Runtime Init RPM can be verified against a SHA256 checksum provided as a release asset on the F5 BIG-IP Runtime Init public Github repository, for example: https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/1.0.0/f5-bigip-runtime-init-1.0.0-1.gz.run.sha256.
- F5 BIG-IP Runtime Init: The self-extracting installer script extracts, verifies, and installs the F5 BIG-IP Runtime Init RPM package. Package files are signed by F5 and automatically verified using GPG.
- F5 Automation Toolchain components: F5 BIG-IP Runtime Init downloads, installs, and configures the F5 Automation Toolchain components. Although it is optional, F5 recommends adding the extensionHash field to each extension install operation in the configuration file. The presence of this field triggers verification of the downloaded component package checksum against the provided value. The checksum values are published as release assets on each extension's public Github repository, for example: https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.18.0/f5-appsvcs-3.18.0-4.noarch.rpm.sha256

The following configuration file will verify the Declarative Onboarding and Application Services extensions before configuring AS3 from a local file:

```yaml
runtime_parameters: []
extension_packages:
    install_operations:
        - extensionType: do
          extensionVersion: 1.16.0
          extensionHash: 536eccb9dbf40aeabd31e64da8c5354b57d893286ddc6c075ecc9273fcca10a1
        - extensionType: as3
          extensionVersion: 3.23.0
          extensionHash: de615341b91beaed59195dceefc122932580d517600afce1ba8d3770dfe42d28
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
| 15.1.200000 | 15.1.2 Build 0.0.9 |
| 14.1.300000 | 14.1.3 Build 0.0.7 |

These templates have been tested and validated with the following versions of BIG-IP. 

| BIG-IP Version | Build Number |
| --- | --- |
| 15.1.2 | 0.0.9 |
| 14.1.3 | 0.0.7 |

## Supported instance types and hypervisors

- For a list of supported Azure instance types for this solution, see the [Azure instances for BIG-IP VE](http://clouddocs.f5.com/cloud/public/v1/azure/Azure_singleNIC.html#azure-instances-for-big-ip-ve).

- For a list of versions of the BIG-IP Virtual Edition (VE) and F5 licenses that are supported on specific hypervisors and Microsoft Azure, see [supported-hypervisor-matrix](https://support.f5.com/kb/en-us/products/big-ip_ltm/manuals/product/ve-supported-hypervisor-matrix.html).


## Installation

You have two options for deploying this solution:

- Using the Azure deploy buttons
- Using [CLI Tools](#azure-cli-20-script-example)

### Azure deploy buttons

Use the appropriate button below to deploy:

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FF5Networks%2Ff5-azure-arm-templates-v2%2Fv1.2.0.0%2Fexamples%2Fquickstart%2Fazuredeploy.json)


### Programmatic deployments

As an alternative to deploying through the Azure Portal (GUI), each solution provides an example Azure CLI 2.0 command to deploy the ARM template. The following example deploys a 3 NIC BIG-IP VE with a public management IP address and 4 public external IP addresses.

#### Azure CLI (2.0) Script Example

```bash
RESOURCE_GROUP="myGroupName"
DEPLOY_PARAMS='{"templateBaseUrl":{"value":"https://cdn.f5.com/product/cloudsolutions/"},"artifactLocation":{"value":"f5-azure-arm-templates-v2/v1.2.0/examples/"},"uniqueString":{"value":"<value>"},"sshKey":{"value":"<value>"},"instanceType":{"value":"Standard_DS4_v2"},"image":{"value":"f5-networks:f5-big-ip-byol:f5-big-all-2slot-byol:15.1.200000"},"appContainerName":{"value":"f5devcentral/f5-demo-app:1.0.1"},"restrictedSrcAddressMgmt":{"value":"<value>"},"bigIpRuntimeInitConfig":{"value":"https://raw.githubusercontent.com/f5networks/f5-azure-arm-templates-v2/v0.0.2/examples/quickstart/bigip-configurations/runtime-init-conf-3nic-byol.yaml"},"useAvailabilityZones":{"value":False},"numNics":{"value":3},"usePublicMgmtAddress":{"value":True},"numberPublicExternalIPAddresses":{"value":4}}'
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
- Obtain the IP address of the WAF service:
  - **Console**: Navigate to Resource Groups->**your resource group name**->Deployments->**your parent template deployment name**->Outputs->appPublicIps
  - **Azure CLI**: ```az group deployment show --name **your parent template deployment name** --resource-group **your resource group name** -o json --query properties.outputs.appPublicIps.value[0]```
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

There are generally two classes of issues:

1. Template deployment itself failed
2. Resource(s) within the template failed to deploy

To verify that all templates deployed successfully, follow the instructions under **Validating the Deployment** above to locate the failed deployment(s).

Click on the name of a failed deployment and then click Events. Click the link in the red banner at the top of the deployment overview for details about the failure cause. 

Additionally, if the template passed validation but individual template resources have failed to deploy, you can see more information by expanding Deployment Details, then clicking on the Operation details column for the failed resource. **When creating a Github issue for a template, please include as much information as possible from the failed Azure deployment/resource events.**

Common deployment failure causes include:
- Required fields were left empty or contained incorrect values (input type mismatch, prohibited characters, malformed JSON, etc.) causing template validation failure
- Insufficient permissions to create the deployment or resources created by a deployment
- Resource limitations (exceeded limit of IP addresses or compute resources, etc.)
- Azure service issues (these will usually surface as 503 internal server errors in the deployment status error message)

If all deployments completed successfully, wait a few minutes, then log in to the BIG-IP instance(s) via SSH to confirm BIG-IP deployment was successful (for example, if startup scripts completed as expected on the BIG-IPs). To verify BIG-IP deployment, perform the following steps:
- Obtain the IP address of the BIG-IP instance(s):
  - **Console**: Navigate to Resource Groups->**your resource group name**->Overview->**instance name**->Essentials->Public or Private IP address
  - **Azure CLI**: 
    - Public IPs: ```az vm show --name **instance name** -g **your resource group name** -d -o json --query publicIps```
    - Private IPs: ```az vm show --name **instance name** -g **your resource group name** -d -o json --query privateIps```
- Login to each instance via SSH:
  - **SSH key authentication**: ```ssh azureuser@<IP Address from Output> -i <path to private key corresponding to sshKey>```
  - **Password authentication**: ```ssh quickstart@<IP Address from Output>``` Use the virtual machine instance name as the temporary password when prompted, then change the temporary password immediately
- Check the logs:
  - /var/log/cloud/startup-script.log: This file contains events that happen prior to execution of f5-bigip-runtime-init. If the files required by the deployment fail to download, for example, you will see those events logged here.
  - /var/log/cloud/bigipRuntimeInit.log: This file contains events logged by the f5-bigip-runtime-init onboarding utility. If the configuration is invalid causing onboarding to fail, you will see those events logged here. If deployment is successful, you will see an event with the body "All operations completed successfully".
  - /var/log/restnoded/restnoded.log: This file contains events logged by the F5 Automation Toolchain components. If an Automation Toolchain declaration fails to deploy, you will see those events logged here.

If you are unable to login to the BIG-IP instance(s), you can navigate to Resource Groups->**your resource group name**->Overview->**instance name**->Support and Troubleshooting->Serial console for additional information from Azure.


## Configuration Example

The following is an example configuration diagram for this solution deployment. In this scenario, management access to the 3NIC BIG-IP VE appliance is through an Azure network interface configured with a private IP address only. Application traffic from the Internet traverses an external network interface configured with both public and private IP addresses. Traffic to the application instances traverses an internal network interface configured with a private IP address.

![Configuration Example](https://github.com/F5Networks/f5-azure-arm-templates-v2/blob/master/examples/quickstart/byol/diagram.png)


## Documentation

For more information on F5 solutions for Azure, including manual configuration procedures for some deployment scenarios, see the Azure section of [Public Cloud Docs](http://clouddocs.f5.com/cloud/public/v1/).


## Getting Help

Due to the heavy customization requirements of external cloud resources and BIG-IP configurations in these solutions, F5 does not provide technical support for deploying, customizing, or troubleshooting the templates themselves. However, the various underlying products and components used (for example: F5 BIG-IP Virtual Edition, F5 BIG-IP Runtime Init, Automation Toolchain extensions, and Cloud Failover Extension (CFE)) in the solutions located here are F5-supported and capable of being deployed with other orchestration tools. Read more about [Support Policies](https://www.f5.com/company/policies/support-policies). Problems found with the templates deployed as-is should be reported via a GitHub issue.


For help with authoring and support for custom CST2 templates, we recommend engaging F5 Professional Services (PS).


### Filing Issues

Use the **Issues** link on the GitHub menu bar in this repository for items such as enhancement or feature requests and bugs found when deploying the example templates as-is. Tell us as much as you can about what you found and how you found it.
