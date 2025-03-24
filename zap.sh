PORT=$(kubectl -n default get svc devsecops-svc -o json | jq -r '.spec.ports[0].nodePort')

chmod 755 $(pwd)

docker run --rm --network host -v $(pwd):/zap/wrk/:rw -t zaproxy/zap-stable zap_api_scan.py \
    -t "$APPLICATION_URL:$PORT/v3/api-docs" \
    -f openapi \
    -r /zap/wrk/zap-report.html \
    -I

exit_code=$?

if [ "$exit_code" -ne 0 ]; then
    exit 1
fi