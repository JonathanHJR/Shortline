#!/bin/bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 > /tmp/promfwd.log 2>&1 &
PF_PID=$!
sleep 4
echo '--- raw shortline_http_requests_total ---'
curl -s -G http://localhost:9090/api/v1/query --data-urlencode 'query=shortline_http_requests_total'
echo
echo '--- rate(shortline_http_requests_total[5m]) ---'
curl -s -G http://localhost:9090/api/v1/query --data-urlencode 'query=rate(shortline_http_requests_total[5m])'
echo
kill $PF_PID 2>/dev/null
