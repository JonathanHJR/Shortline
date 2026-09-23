#!/bin/bash
PASS=$(kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d)
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80 > /tmp/grafanafwd.log 2>&1 &
PF_PID=$!
sleep 4
echo "--- dashboards ---"
curl -s -u "admin:$PASS" http://localhost:3000/api/search?query=Shortline
echo
kill $PF_PID 2>/dev/null
