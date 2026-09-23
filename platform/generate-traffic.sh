#!/bin/bash
kubectl run traffic-gen --image=curlimages/curl:latest --restart=Never --command -- sh -c 'i=0; while [ $i -lt 60 ]; do curl -s -o /dev/null http://shortline.default.svc.cluster.local/health; curl -s -o /dev/null -X POST -H "Content-Type: application/json" -d "{\"url\":\"https://example.com\"}" http://shortline.default.svc.cluster.local/shorten; curl -s -o /dev/null http://shortline.default.svc.cluster.local/nonexistent-code; sleep 0.3; i=$((i+1)); done'
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/traffic-gen --timeout=60s
kubectl delete pod traffic-gen
