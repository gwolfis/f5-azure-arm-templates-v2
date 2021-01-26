[admin@alexap2-vmss-0:Active:Standalone] ~ # cat /var/lib/waagent/customData | base64 -d
#!/bin/bash -x

# VARS
LOG_DIR="/var/log/cloud"
CONFIG_DIR="/config/cloud"
DOWNLOAD_DIR="/var/config/rest/downloads"
# VARS FROM TEMPLATE
PACKAGE_URL='https://cdn.f5.com/product/cloudsolutions/f5-bigip-runtime-init/develop/develop/dist/f5-bigip-runtime-init-1.1.0-1.gz.run'
RUNTIME_CONFIG='https://raw.githubusercontent.com/f5-applebaum/deployments-v2/0.0.1/dev/bigip-configurations/bigip-config.yaml'

# Log to local file and serial console
mkdir -p ${CONFIG_DIR} ${LOG_DIR} ${DOWNLOAD_DIR}
LOG_FILE=${LOG_DIR}/startup-script.log
touch ${LOG_FILE}
npipe=/tmp/$$.tmp
trap "rm -f $npipe" EXIT
mknod $npipe p
tee <$npipe -a ${LOG_FILE} &
tee <$npipe -a /dev/ttyS0 &
exec 1>&-
exec 1>$npipe
exec 2>&1

# Optional optimizations required as early as possible in boot
/usr/bin/setdb provision.extramb 500
/usr/bin/setdb restjavad.useextramb true
[[ "! grep 'provision asm' /defaults/bigip_base.conf" ]] && mount -o remount,rw /usr && echo "sys provision asm { level nominal }" | tee -a /defaults/bigip_base.conf /config/bigip_base.conf && mount -o remount,ro /usr

# Render or download f5-bigip-runtime-init config
if egrep -qi '^https?://' <<<${RUNTIME_CONFIG}; then
 curl -v --retry 60 --connect-timeout 5 --fail -L ${RUNTIME_CONFIG} -o ${CONFIG_DIR}/runtime-init.conf
else
 printf '%s\n' "${RUNTIME_CONFIG}" > ${CONFIG_DIR}/runtime-init.conf
fi

# Download and install f5-bigip-runtime-init package
for i in {1..30}; do
  curl -v --retry 1 --connect-timeout 5 --fail -L ${PACKAGE_URL} -o ${DOWNLOAD_DIR}/f5-bigip-runtime-init.gz.run && break || sleep 10
done
bash ${DOWNLOAD_DIR}/f5-bigip-runtime-init.gz.run -- '--cloud azure'
f5-bigip-runtime-init --config-file ${CONFIG_DIR}/runtime-init.conf