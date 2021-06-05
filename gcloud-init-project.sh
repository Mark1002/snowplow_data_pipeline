#!/bin/bash

# Init whole project. Creates colector instances, BQ, pubsubs, cloud storage etc.
# You have to finish the process manualy by configuring load balancer

source "./gcloud-config.sh"
echo "[start] Preparing $GCP_NAME"

UUID=$(uuidgen)

gcloud config set project $GCP_NAME

#prepare config files from template

mkdir ./configs
cd ./templates/
TEMP_BUCKET_ESC=$(echo $TEMP_BUCKET |  sed -e 's/[\/&]/\\&/g')

echo "[info] Preparinng scripts from templates"
for file in `ls ./*.*`
do
    echo "Procesing template ${file}"
    cat $file | sed -e "s/%REGION%/${REGION}/g"  -e "s/%TEMPBUCKET%/${TEMP_BUCKET_ESC}/g"  -e "s/%PROJECTID%/${GCP_NAME}/g" | \
    sed -e "s/%UUID%/${UUID}/g" -e "s/%SERVICEACCOUNT%/${SERVICEACCOUNT}/g"\
    > ../configs/$file
done
cd ..

echo "[info] Cresting PUB/SUB topics and subscriptions"
#collector pubsub
gcloud alpha pubsub topics create "collected-good" --message-storage-policy-allowed-regions="$REGION"
gcloud alpha pubsub topics create "collected-bad" --message-storage-policy-allowed-regions="$REGION"
gcloud pubsub subscriptions create "collected-good-sub" --topic="collected-good" --expiration-period=365d
gcloud pubsub subscriptions create "collected-bad-sub" --topic="collected-bad" --expiration-period=365d

#enriched pubsub
gcloud alpha pubsub topics create enriched-bad --message-storage-policy-allowed-regions="$REGION"
gcloud alpha pubsub topics create enriched-good --message-storage-policy-allowed-regions="$REGION"
gcloud alpha pubsub topics create enriched-pii --message-storage-policy-allowed-regions="$REGION"

gcloud pubsub subscriptions create "enriched-good-sub" --topic="enriched-good" --expiration-period=365d
gcloud pubsub subscriptions create "enriched-bad-sub" --topic="enriched-bad" --expiration-period=365d
gcloud pubsub subscriptions create "enriched-pii-sub" --topic="enriched-pii" --expiration-period=365d

#bigquery
gcloud alpha pubsub topics create bq-bad-rows --message-storage-policy-allowed-regions="$REGION"
gcloud alpha pubsub topics create bq-failed-inserts --message-storage-policy-allowed-regions="$REGION"
gcloud alpha pubsub topics create bq-types --message-storage-policy-allowed-regions="$REGION"

gcloud pubsub subscriptions create "bq-types-sub" --topic="bq-types" --expiration-period=365d
gcloud pubsub subscriptions create "bq-bad-rows-sub" --topic="bq-bad-rows" --expiration-period=365d
gcloud pubsub subscriptions create "bq-failed-inserts" --topic="bq-failed-inserts" --expiration-period=365d

#test subscriptions
gcloud pubsub subscriptions create "collected-good-sub-test" --topic="collected-good" --expiration-period=365d
gcloud pubsub subscriptions create "enriched-good-sub-test" --topic="enriched-good" --expiration-period=365d

echo "[info] Creating temp bucket $TEMP_BUCKET for confugurations"
#prepare temp buckets for configurations
gsutil mb -l US "$TEMP_BUCKET"

gsutil cp ./configs/iglu_config.json $TEMP_BUCKET/config/
gsutil cp ./configs/collector.config $TEMP_BUCKET/config/
#gsutil cp ./configs/enrich.config $TEMP_BUCKET/config/
gsutil cp ./configs/bigqueryloader_config.json $TEMP_BUCKET/config/

echo "[info] Preparing bigquery dataset $GCP_NAME:snowplow"
#prepare BigQuery
bq --location=US mk "$GCP_NAME:snowplow"


###################################### Colector group + loadbalancer ###################################################
# create vpc network
echo "[info] Preparing vpc network"
if [[ $(gcloud compute networks list --filter snowplow-vpc) == "" ]] ; then
    gcloud compute networks create snowplow-vpc \
        --project="${GCP_NAME}" --description='for snowplow' \
        --subnet-mode=auto --mtu=1460 --bgp-routing-mode=regional
else
    echo "[info] vpc network snowplow-vpc aleady exist!"
fi

# collector instances template
echo "[info] Preparing compute instance group machine template"
if [[ $(gcloud compute instance-templates list --filter snowplow-collector-template) == "" ]] ; then
    gcloud compute instance-templates create snowplow-collector-template \
        --machine-type=${COLLECTOR_MACHINE_TYPE} \
        --network=projects/${GCP_NAME}/global/networks/snowplow-vpc \
        --network-tier=PREMIUM \
        --metadata-from-file=startup-script=./configs/collector_startup.sh \
        --maintenance-policy=MIGRATE --service-account=$SERVICEACCOUNT \
        --scopes=https://www.googleapis.com/auth/pubsub,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/trace.append,https://www.googleapis.com/auth/devstorage.read_only \
        --tags=snowplow-collector,http-server,https-server \
        --image=${IMAGE} \
        --image-project=${IMAGE_PROJECT} \
        --boot-disk-size=10GB \
        --boot-disk-type=pd-standard \
        --boot-disk-device-name=snowplow-collector-template
else
    echo "[info] snowplow-collector-template aleady exist!"
fi

echo "[info] Preparing firewall rule for port 8080"
if [[ $(gcloud compute firewall-rules list --filter snowplow-collector-rule) == "" ]] ; then
    gcloud compute firewall-rules create snowplow-collector-rule --direction=INGRESS \
        --priority=1000 --network=snowplow-vpc --action=ALLOW \
        --rules=tcp:8080 --source-ranges=130.211.0.0/22,35.191.0.0/16 \
        --target-tags=snowplow-collector
else
    echo "[info] firewall-rules snowplow-collector-rule aleady exist!"
fi

echo "[info] Preparing health check"
if [[ $(gcloud compute health-checks list --filter snowplow-collector-health-check) == "" ]] ; then
    gcloud compute health-checks create http "snowplow-collector-health-check" \
        --timeout "5" --check-interval "10" \
        --unhealthy-threshold "3" --healthy-threshold "2" \
        --port "8080" --request-path "/health"
else
    echo "[info] snowplow-collector-health-check aleady exist!"
fi

echo "[info] Preparing compute instance group"
if [[ $(gcloud compute instance-groups managed list --filter snowplow-collector-group) == "" ]] ; then
    gcloud beta compute instance-groups managed create snowplow-collector-group \
        --base-instance-name=snowplow-collector-group \
        --template=snowplow-collector-template --size=1 \
        --health-check=snowplow-collector-health-check \
        --initial-delay=300 --region "${REGION}"

    echo "[info] Seting autoscaling for group"
    gcloud compute instance-groups managed set-autoscaling "snowplow-collector-group" \
        --cool-down-period "60" --max-num-replicas "2" --region "${REGION}" \
        --min-num-replicas "1" --target-cpu-utilization "0.6"

    echo "[info] Setting named-ports"
    gcloud compute instance-groups managed set-named-ports snowplow-collector-group \
        --region "${REGION}" --named-ports http:8080
else
    echo "[info] instance group snowplow-collector-group aleady exist!"
fi

echo "[info] Prepare creating load balancer"
## static external IP
echo "[info] create static ip..."
if [[ $(gcloud compute addresses list --filter snowplow-ip) == "" ]] ; then
    gcloud compute addresses create snowplow-ip --project=${GCP_NAME} --global
else
    echo "[info] static ip already exist!"
fi

## backend service
 echo "[info] create backend service..."
if [[ $(gcloud compute backend-services list --filter snowplow-backend) == "" ]] ; then
    gcloud compute backend-services create snowplow-backend \
        --health-checks=snowplow-collector-health-check \
        --protocol HTTP --port-name http --timeout 30 --global
    gcloud compute backend-services add-backend snowplow-backend \
        --instance-group snowplow-collector-group \
        --balancing-mode UTILIZATION \
        --max-utilization 0.8 \
        --capacity-scaler 1.0 \
        --instance-group-region "${REGION}" \
        --global
else
    echo "[info] backend service already exist!"
fi

### url map
echo "[info] create url map..."
if [[ $(gcloud compute url-maps list --filter snowplow-lb) == "" ]] ; then
    gcloud compute url-maps create snowplow-lb --default-service snowplow-backend --global
else
    echo "[info] url map already exist!"
fi

### http proxy
 echo "[info] create http proxy..."
if [[ $(gcloud compute target-http-proxies list --filter snowplow-lb-target-proxy) == "" ]] ; then
    gcloud compute target-http-proxies create snowplow-lb-target-proxy --url-map snowplow-lb
else
    echo "[info] http proxy already exist!"
fi

### forwarding rule
echo "[info] create forwarding rule..."
if [[ $(gcloud compute forwarding-rules list --filter snowplow-frontend) == "" ]] ; then
    gcloud compute forwarding-rules create snowplow-frontend \
        --address=snowplow-ip \
        --global \
        --target-http-proxy=snowplow-lb-target-proxy \
        --ports=80
else
    echo "[info] forwarding rule already exist!"
fi

collector_ip=$(gcloud compute addresses list | grep snowplow-ip | cut -d ' ' -f3)
echo "[info] All done. Collector runs at $collector_ip. Wait until scala-stream-collector and load balancer starts (cca. 2-5mins)"
echo "[test] curl http://$collector_ip/health"
echo "[test] curl http://$collector_ip/i"
echo "[test] and then:"
echo "[test] gcloud pubsub subscriptions pull --auto-ack good-sub-test"
