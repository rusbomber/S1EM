#!/bin/bash
mv env.sample .env
echo "##########################################"
echo "###### CONFIGURING ACCOUNT ELASTIC #######"
echo "##########################################"
echo  
password=$(cat .env | head -n 1 | awk -F= '{print $2}')
echo "The elastic password set in .env:" $password
echo
read -p "Confirm (y/n) ?" confirm

case $confirm in
        [yY][eE][sS]|[yY])
        sed -i "s/changeme/$password/g" .env cortex/application.conf elastalert/elastalert.yaml filebeat/filebeat.yml metricbeat/metricbeat.yml kibana/kibana.yml auditbeat/auditbeat.yml logstash/pipeline/03_output.conf
        sed -i "s/elastic_opencti/$password/g" docker-compose.yml
        ;;
        [nN][oO]|[nN])
        ;; *)
        echo "Invalid input ..."
     exit 1
     ;;
esac
echo
echo
echo "##########################################"
echo "#### CONFIGURING MONITORING INTERFACE ####"
echo "##########################################"
echo
ip a | egrep "ens[[:digit:]]{1,3}:|eth[[:digit:]]{1,3}:"
echo
echo
read -r -p "Enter the monitoring interface (ex:ens32):" monitoring_interface
monitoring_interface=$monitoring_interface
sed -i "s/network_monitoring/$monitoring_interface/g" docker-compose.yml
echo
echo
echo "##########################################"
echo "######### GENERATE CERTIFICATE ###########"
echo "##########################################"
mkdir ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/server.key -out ssl/server.crt
chmod 600 ssl/server.key ssl/server.crt
echo
docker-compose pull
docker-compose up -d
sleep 45
echo
echo "##########################################"
echo "######## UPDATE SURICATA RULES ###########"
echo "##########################################"
echo
docker exec -ti suricata suricata-update update-sources
docker exec -ti suricata suricata-update --no-test
echo
echo "##########################################"
echo "########## UPDATE YARA RULES #############"
echo "##########################################"
echo
mkdir tmp
git clone https://github.com/Yara-Rules/rules.git tmp
rm -fr stoq/rules/yara/*
rm tmp/malware/MALW_AZORULT.yar
mv tmp/* stoq/rules/yara/
rm -fr tmp
cd stoq/rules/yara
bash index_gen.sh
docker restart stoq
