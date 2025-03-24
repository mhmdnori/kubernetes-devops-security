#!/bin/bash

PORT=$(kubectl -n default get svc devsecops-svc -o json | jq -r '.spec.ports[0].nodePort')

chmod 755 $(pwd)

docker run --rm --network host -v $(pwd):/zap/wrk/:rw -t zaproxy/zap-stable zap-api-scan.py \
    -t "$APPLICATION_URL:$PORT/v3/api-docs" \
    -f openapi \
    -r /zap/owasp-zap-report/zap-report.html

exit_code=$?

mkdir -p owasp-zap-report
mv zap-report.html owasp-zap-report

if [ "$exit_code" -ne 0 ]; then
    exit 1
fi
