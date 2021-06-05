#!/bin/bash

source "./gcloud-config.sh"

# clean frontend service
if [[ $(gcloud compute forwarding-rules list --filter snowplow-frontend) != "" ]] ; then
    echo "[info] delete snowplow-frontend"
    gcloud compute forwarding-rules delete snowplow-frontend -q --global
else
    echo "[info] snowplow-frontend not exist!"
fi

# clean http proxy
if [[ $(gcloud compute target-http-proxies list --filter snowplow-lb-target-proxy) != "" ]] ; then
    echo "[info] delete snowplow-lb-target-proxy"
    gcloud compute target-http-proxies delete snowplow-lb-target-proxy -q
else
    echo "[info] http proxy not exist!"
fi

# clean url maps
if [[ $(gcloud compute url-maps list --filter snowplow-lb) != "" ]] ; then
    echo "[info] delete url-maps"
    gcloud compute url-maps delete snowplow-lb -q --global
else
    echo "[info] url-maps not exist!"
fi

# clean backend service
if [[ $(gcloud compute backend-services list --filter snowplow-backend) != "" ]] ; then
    echo "[info] delete snowplow-backend"
    gcloud compute backend-services delete snowplow-backend -q --global
else
    echo "[info] backend-services not exist!"
fi

# clean instance group
if [[ $(gcloud compute instance-groups managed list --filter snowplow-collector-group) != "" ]] ; then
    echo "[info] delete snowplow-collector-group"
    gcloud compute instance-groups managed delete snowplow-collector-group -q --region ${REGION}
else
    echo "[info] instance group snowplow-collector-group not exist!"
fi

# clean instance template
if [[ $(gcloud compute instance-templates list --filter snowplow-collector-template) != "" ]] ; then
    echo "[info] delete snowplow-collector-template"
    gcloud compute instance-templates delete snowplow-collector-template -q
else
    echo "[info] snowplow-collector-template not exist!"
fi

# clean static ip
if [[ $(gcloud compute addresses list --filter snowplow-ip) != "" ]] ; then
    echo "[info] delete snowplow-ip"
    gcloud compute addresses delete snowplow-ip -q --global
else
    echo "[info] static ip not exist!"
fi

# clean firewall-rules
if [[ $(gcloud compute firewall-rules list --filter snowplow-collector-rule) != "" ]] ; then
    echo "[info] delete firewall-rules"
    gcloud compute firewall-rules delete snowplow-collector-rule -q
else
    echo "[info] firewall-rules not exist!"
fi

# clean snowplow-vpc
if [[ $(gcloud compute networks list --filter snowplow-vpc) != "" ]] ; then
    echo "[info] delete vpc networks snowplow-vpc"
    gcloud compute networks delete snowplow-vpc -q
else
    echo "[info] vpc networks snowplow-vpc not exist!"
fi

# clean gcs bucket
if [[ $(gsutil ls | grep ${TEMP_BUCKET}) != "" ]]; then
    echo "[info] delete ${TEMP_BUCKET}"
    gsutil rm -r ${TEMP_BUCKET}
else
    echo "[info] ${TEMP_BUCKET} not exist!"
fi

# clean pubsub
if [[ $(gcloud pubsub subscriptions list --filter enriched-good-sub) != "" ]]; then
    gcloud pubsub subscriptions delete enriched-good-sub
fi
if [[ $(gcloud pubsub topics list --filter enriched-good) != "" ]]; then
    gcloud pubsub topics delete enriched-good
fi
if [[ $(gcloud pubsub subscriptions list --filter collected-good-sub) != "" ]]; then
    gcloud pubsub subscriptions delete collected-good-sub
fi
if [[ $(gcloud pubsub topics list --filter collected-good) != "" ]]; then
    gcloud pubsub topics delete collected-good
fi
if [[ $(gcloud pubsub subscriptions list --filter enriched-bad-sub) != "" ]]; then
    gcloud pubsub subscriptions delete enriched-bad-sub
fi
if [[ $(gcloud pubsub topics list --filter enriched-bad) != "" ]]; then
    gcloud pubsub topics delete enriched-bad
fi
if [[ $(gcloud pubsub subscriptions list --filter collected-bad-sub) != "" ]]; then
    gcloud pubsub subscriptions delete collected-bad-sub
fi
if [[ $(gcloud pubsub topics list --filter collected-bad) != "" ]]; then
    gcloud pubsub topics delete collected-bad
fi
if [[ $(gcloud pubsub subscriptions list --filter bq-types-sub) != "" ]]; then
    gcloud pubsub subscriptions delete bq-types-sub
fi
if [[ $(gcloud pubsub topics list --filter bq-types) != "" ]]; then
    gcloud pubsub topics delete bq-types
fi
if [[ $(gcloud pubsub subscriptions list --filter bq-failed-inserts) != "" ]]; then
    gcloud pubsub subscriptions delete bq-failed-inserts
fi
if [[ $(gcloud pubsub topics list --filter bq-failed-inserts) != "" ]]; then
    gcloud pubsub topics delete bq-failed-inserts
fi
if [[ $(gcloud pubsub subscriptions list --filter bq-bad-rows-sub) != "" ]]; then
    gcloud pubsub subscriptions delete bq-bad-rows-sub
fi
if [[ $(gcloud pubsub topics list --filter bq-bad-rows) != "" ]]; then
    gcloud pubsub topics delete bq-bad-rows
fi
if [[ $(gcloud pubsub subscriptions list --filter enriched-pii-sub) != "" ]]; then
    gcloud pubsub subscriptions delete enriched-pii-sub
fi
if [[ $(gcloud pubsub topics list --filter enriched-pii) != "" ]]; then
    gcloud pubsub topics delete enriched-pii
fi