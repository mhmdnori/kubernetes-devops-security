#!/bin/bash

PORT=$(kubectl -n default get svc devsecops-svc -o json | jq .spec.ports[].nodePort)

chmod 777 $(pwd)
docker run --rm -v ${workspace}:/zap -t zaproxy/zap-stable zap/zap-api-scan.py -t $APPLICATION_URL:$PORT/v3/api-docs -f openapi -r zap-report.html

exit_code=$?

sudo mkdir -p owasp-zap-report
sudo mv zap-report.html owasp-zap-report

if [[${exit_code} -ne 0]]; then
    exit 1;
fi;