Deploy app:

> kubectl apply -f deployment.yaml
> kubectl port-forward hello-kubernetes-xxx 8080:8080

curl http://localhost:8080

---

Deploy load balance to have a public endpoint for the web:

> kubectl apply -f service-loadbalancer.yaml
> kubectl describe service hello-kubernetes

---

Deploy kubernetes metrics server

> wget -O v0.3.6.tar.gz https://codeload.github.com/kubernetes-sigs/metrics-server/tar.gz/v0.3.6 && tar -xzf v0.3.6.tar.gz
> kubectl apply -f metrics-server-0.3.6/deploy/1.8+/

Deploy kubernetes dashboard

> kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml
> kubectl proxy

Access kubernetes dashboard here:

http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

Create a `ClusterRoleBinding`
> kubectl apply -f https://raw.githubusercontent.com/hashicorp/learn-terraform-provision-eks-cluster/master/kubernetes-dashboard-admin.rbac.yaml

Generate token for dashboard
> kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep service-controller-token | awk '{print $1}')