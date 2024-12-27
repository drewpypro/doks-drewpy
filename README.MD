# doks-drewpy

# Goals
- Single build pipeline that creates doks cluster and required infrastructure through terraform. 
- Deploy k8s with istio, argocd and cert-manager. 
- Create Cloudflare DNS
- Expose an app through WAF rules and test. 


# Notes
- Created doks (in UI)
- Created new do api token with appropriate scopes (in UI). 
- Authed to doctl, kubectl and docker
    ```
    # Auth DO
    doctl auth remove --context <old-context>
    doctl auth init --context doks-testing --access-token
    Please authenticate doctl for use with your DigitalOcean account. You can generate a token in the control panel at https://cloud.digitalocean.com/account/api/tokens

    ❯ Enter your access token:  ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●

    Validating token... ✔

    # Auth Kubectl
    doctl kubernetes cluster kubeconfig save e811baf4-bf2d-44f1-8514-bd86d17ac6bd --context doks-testing
    Notice: Adding cluster credentials to kubeconfig file found in "/root/.kube/config"
    Notice: Setting current-context to do-nyc3-k8s-1-31-1-do-5-nyc3-1735319477867

    # Auth Docker
    docker info
    cat ~/.docker/config.json
    rm ~/.docker/config.json
    docker logout
    docker login
    ```

- Perform validation commands
    ```
    kubectl config get-contexts
    CURRENT   NAME                                                    CLUSTER                                                 AUTHINFO                                                NAMESPACE
    *         do-nyc3-k8s-1-31-1-do-5-nyc3-1735319477867              do-nyc3-k8s-1-31-1-do-5-nyc3-1735319477867              do-nyc3-k8s-1-31-1-do-5-nyc3-1735319477867-admin


    kubectl cluster-info
    Kubernetes control plane is running at https://e811baf4-bf2d-44f1-8514-bd86d17ac6bd.k8s.ondigitalocean.com
    CoreDNS is running at https://e811baf4-bf2d-44f1-8514-bd86d17ac6bd.k8s.ondigitalocean.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy


    kubectl get nodes -o wide
    NAME                     STATUS   ROLES    AGE    VERSION   INTERNAL-IP   EXTERNAL-IP      OS-IMAGE                         KERNEL-VERSION   CONTAINER-RUNTIME
    drewpy-doks-pool-ejbh2   Ready    <none>   9m     v1.31.1   10.10.10.3    161.35.138.212   Debian GNU/Linux 12 (bookworm)   6.1.0-27-amd64   containerd://1.6.31
    drewpy-doks-pool-ejbhl   Ready    <none>   9m7s   v1.31.1   10.10.10.2    138.197.88.128   Debian GNU/Linux 12 (bookworm)   6.1.0-27-amd64   containerd://1.6.31

    doctl kubernetes cluster list
    ID                                      Name                                  Region    Version        Auto Upgrade    Status     Node Pools
    e811baf4-bf2d-44f1-8514-bd86d17ac6bd    k8s-1-31-1-do-5-nyc3-1735319477867    nyc3      1.31.1-do.5    false           running    drewpy-doks-pool

    doctl kubernetes cluster kubeconfig show e811baf4-bf2d-44f1-8514-bd86d17ac6bd
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: <-->
    server: https://e811baf4-bf2d-44f1-8514-bd86d17ac6bd.k8s.ondigitalocean.com
    name: do-nyc3-k8s-1-31-1-do-5-nyc3-1735319477867
    contexts:
    - context:
        cluster: do-nyc3-k8s-1-31-1-do-5-nyc3-1735319477867
        user: do-nyc3-k8s-1-31-1-do-5-nyc3-1735319477867-admin
    name: do-nyc3-k8s-1-31-1-do-5-nyc3-1735319477867
    current-context: do-nyc3-k8s-1-31-1-do-5-nyc3-1735319477867
    kind: Config
    preferences: {}
    users:
    - name: do-nyc3-k8s-1-31-1-do-5-nyc3-1735319477867-admin
    user:
        token: dop_v1_somekey
    ```

- Build app, create/auth DO registry and push (doks-app.py)
    ```
    ls doks-testing
    Dockerfile  doks-app.py  requirements.txt

    docker build -t doks-app .
    docker images
    docker run -ti -p 80:80 doks-app
    
    doctl registry create drewpy-registry
    Name               Endpoint                                     Region slug
    drewpy-registry    registry.digitalocean.com/drewpy-registry    sfo2
    
    docker tag doks-app registry.digitalocean.com/drewpy-registry/doks-app

    docker push registry.digitalocean.com/drewpy-registry/doks-app
    Using default tag: latest
    The push refers to repository [registry.digitalocean.com/drewpy-registry/doks-app]
    df36e1fc2d4b: Pushed
    bc9d05344666: Pushed
    59b07664e6d9: Pushed
    aef2d4757f52: Pushed
    ec29f1f841c6: Pushed
    a9682e91d63b: Pushed
    6d58389117c3: Pushing [==================================================>]  597.1MB
    6d58389117c3: Pushed
    a4fd1e7df47e: Pushed
    2f7b6d216a37: Pushed

    latest: digest: sha256:18549a78f1980a0106c6b45785d755f2996ab4d696d7d0b39a4f3d3239b3c0db size: 2420

- Test registry works
    ```
    docker run -p 80:80 registry.digitalocean.com/drewpy-registry/doks-app
    * Serving Flask app 'doks-app'
    * Debug mode: off
    WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
    * Running on all addresses (0.0.0.0)
    * Running on http://127.0.0.1:80
    * Running on http://172.17.0.2:80
    Press CTRL+C to quit
    172.17.0.1 - - [27/Dec/2024 17:56:01] "GET / HTTP/1.1" 200 -
    172.17.0.1 - - [27/Dec/2024 17:56:03] "GET / HTTP/1.1" 200 -
    ```

- Create registry secret and patch default serviceaccount
    ```
    doctl registry kubernetes-manifest | kubectl apply -f -
    secret/registry-drewpy-registry created

    kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "registry-drewpy-registry"}]}'
    serviceaccount/default patched (no change)
    ```

- Create doks-app deployment, scale and validate
    ```
    kubectl create deployment doks-app --image=registry.digitalocean.com/drewpy-registry/doks-app
    deployment.apps/doks-app created
    
    kubectl get rs -o wide
    NAME                  DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES                                               SELECTOR
    doks-app-7498c74bb5   1         1         0       14s   doks-app     registry.digitalocean.com/drewpy-registry/doks-app   app=doks-app,pod-template-hash=7498c74bb5

    kubectl get pods
    NAME                        READY   STATUS    RESTARTS   AGE
    doks-app-7498c74bb5-xrhpl   1/1     Running   0          46s

    kubectl scale deployment/doks-app --replicas=20
    deployment.apps/doks-app scaled

    kubectl get rs
    NAME                  DESIRED   CURRENT   READY   AGE
    doks-app-7498c74bb5   20        20        2       80s

    kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name --all-namespaces | grep doks-app
    drewpy-doks-pool-ejbh2   doks-app-7498c74bb5-448g6
    drewpy-doks-pool-ejbh2   doks-app-7498c74bb5-4vcm6
    drewpy-doks-pool-ejbh2   doks-app-7498c74bb5-6hdg9
    drewpy-doks-pool-ejbhl   doks-app-7498c74bb5-d6qk2
    drewpy-doks-pool-ejbhl   doks-app-7498c74bb5-hzhcr
    drewpy-doks-pool-ejbh2   doks-app-7498c74bb5-j5242
    drewpy-doks-pool-ejbh2   doks-app-7498c74bb5-k8v4m
    drewpy-doks-pool-ejbh2   doks-app-7498c74bb5-kfl6z
    drewpy-doks-pool-ejbhl   doks-app-7498c74bb5-llj86
    drewpy-doks-pool-ejbhl   doks-app-7498c74bb5-lvlqj
    drewpy-doks-pool-ejbhl   doks-app-7498c74bb5-p2ltl
    drewpy-doks-pool-ejbhl   doks-app-7498c74bb5-p56w5
    drewpy-doks-pool-ejbh2   doks-app-7498c74bb5-q6kfh
    drewpy-doks-pool-ejbh2   doks-app-7498c74bb5-rdjfb
    drewpy-doks-pool-ejbh2   doks-app-7498c74bb5-sn7d5
    drewpy-doks-pool-ejbh2   doks-app-7498c74bb5-t4ghl
    drewpy-doks-pool-ejbhl   doks-app-7498c74bb5-v958s
    drewpy-doks-pool-ejbhl   doks-app-7498c74bb5-wgtsf
    drewpy-doks-pool-ejbhl   doks-app-7498c74bb5-xrhpl
    drewpy-doks-pool-ejbhl   doks-app-7498c74bb5-zv9x2

- Create internet-facing load-balancer
    ```
    kubectl expose deployment doks-app --type=LoadBalancer --port=80 --target-port=80
    service/doks-app exposed

    doctl compute load-balancer list --format Name,Created,IP,Status
    Name                                Created At              IP               Status
    a209c7efc3e704bc78bca4f743c5f134    2024-12-27T18:02:43Z    161.35.248.85    active
    ```

- Build firewall rules on the load-balancer if you're using it
    ```
    doctl compute load-balancer list
    ID                                      IP               Name                                Status    Created At              Region    Size        Size Unit    VPC UUID                                Tag    Droplet IDs            SSL      Sticky Sessions                                Health Check
        Forwarding Rules                                                                                                Disable Lets Encrypt DNS Records
    76e17a56-0576-4a3a-84de-340e1044a853    161.35.248.85    a209c7efc3e704bc78bca4f743c5f134    active    2024-12-27T18:02:43Z    nyc3      lb-small    1            ec6e0bbd-2d77-4a45-bb44-cf32e9d35501           466249215,466249216    false    type:none,cookie_name:,cookie_ttl_seconds:0    protocol:http,port:10256,path:/healthz,check_interval_seconds:3,response_timeout_seconds:5,healthy_threshold:5,unhealthy_threshold:3    entry_protocol:tcp,entry_port:80,target_protocol:tcp,target_port:30785,certificate_id:,tls_passthrough:false    false

    doctl compute load-balancer update 76e17a56-0576-4a3a-84de-340e1044a853 --allow-list ip:69.69.69.69 --region nyc3 --name a209c7efc3e704bc78bca4f743c5f134 --forwarding-rules entry_protocol:tcp,entry_port:80,target_protocol:tcp,target_port:30785,cert
    ificate_id:,tls_passthrough:false
    ID                                      IP               Name                                Status    Created At              Region    Size        Size Unit    VPC UUID                                Tag    Droplet IDs    SSL      Sticky Sessions                                Health Check                                                                                                                   Forwarding Rules
                Disable Lets Encrypt DNS Records
    76e17a56-0576-4a3a-84de-340e1044a853    161.35.248.85    a209c7efc3e704bc78bca4f743c5f134    active    2024-12-27T18:02:43Z    nyc3      lb-small    1            ec6e0bbd-2d77-4a45-bb44-cf32e9d35501                          false    type:none,cookie_name:,cookie_ttl_seconds:0    protocol:http,port:80,path:/,check_interval_seconds:10,response_timeout_seconds:5,healthy_threshold:5,unhealthy_threshold:3    entry_protocol:tcp,entry_port:80,target_protocol:tcp,target_port:30785,certificate_id:,tls_passthrough:false    false
    ```

# References
- [digital-ocean-load-balancer-firewall-how-to-apply](https://www.digitalocean.com/community/questions/digital-ocean-load-balancer-firewall-how-to-apply)
- [add-or-remove-firewall-rules-from-a-load-balancer](https://docs.digitalocean.com/products/networking/load-balancers/how-to/manage/#add-or-remove-firewall-rules-from-a-load-balancer)