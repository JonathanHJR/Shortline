#!/bin/bash
kubectl delete pod curl-loop --ignore-not-found=true --wait=true >/dev/null 2>&1
kubectl run curl-loop --image=curlimages/curl:latest --restart=Never --command -- sh -c 'i=0; while [ $i -lt 100 ]; do curl -s -o /dev/null -w "%{http_code}\n" http://shortline.default.svc.cluster.local/health; sleep 0.1; i=$((i+1)); done'
sleep 3
POD=$(kubectl get pods -l app=shortline -o jsonpath='{.items[0].metadata.name}')
echo "Deleting pod: $POD"
kubectl delete pod "$POD"
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/curl-loop --timeout=30s
echo '--- response code counts (real Service routing) ---'
kubectl logs curl-loop | sort | uniq -c
echo '--- pods after ---'
kubectl get pods -l app=shortline
kubectl delete pod curl-loop
