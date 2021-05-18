# snowplow GCP template

## introduction
todo

## deploy step
todo

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
igluctl lint schemas/<prefix1>.<prefix2>.<prefix3>/<path4>/jsonschema/*
```
3. upload schema file to GCS
```
gsutil cp schemas/com.cloudmile.711/funnel_event/jsonschema/1-0-0 gs://<YOUR_GCS_BUCKET>/schemas/com.cloudmile.711/funnel_event/jsonschema/1-0-0
```

## reference
todo