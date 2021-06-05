# snowplow GCP template

## introduction
todo

## deploy step
### 1. config setting
change environment varible in `gcloud-config-mustr.sh` to your gcp project and save new file to `gcloud-config.sh`.

### 2. set up relate GCP services
execute `gcloud-init-project.sh` to set up relate gcp services.
```
$ ./gcloud-init-project.sh
```
### 3. start & stop dataflow ETL piepline

start pipeline:
```
$ ./start_etl.sh
```
stop pipeline:
```
$ ./stop_etl.sh
```

## custom schema example
1. create the schema dictionary structure and schema file like below:
```
schemas/<prefix1>.<prefix2>.<prefix3>/<sub_path>/jsonschema/1-0-0

schemas
└── com.company.699
    ├── funnel_event
    │   └── jsonschema
    │       └── 1-0-0
    └── user_context
        └── jsonschema
            └── 1-0-0

```

2. validate the format of schema files are correct.
```
$ igluctl lint schemas/<prefix1>.<prefix2>.<prefix3>/<sub_path>/jsonschema/*
```
3. upload schema file to GCS
```
$ gsutil cp schemas/<prefix1>.<prefix2>.<prefix3>/<sub_path>/jsonschema/1-0-0 gs://<YOUR_GCS_BUCKET>/schemas/<prefix1>.<prefix2>.<prefix3>/<sub_path>/jsonschema/1-0-0
```

## reference
1. https://github.com/etnetera-activate/snowplow-gcp-template
