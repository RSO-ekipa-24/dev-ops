# DevOps

This repo contains related configurations and README instruction files.

For this project, we are using `Google Cloud` platform.

We utilize the **GKE Ingress Controller** (`gce`) specifically for **Google-Managed SSL Certificates**.

**Key Benefits:**

* **Automation:** Google automatically provisions and renews certificates every ~90 days.
* **Security:** No manual TLS secrets are stored in the cluster; SSL is terminated at Google's global edge.---
* **Performance:** Faster response times (lower TTFB) compared to Nginx-based routing.
* **Cost:** Multiple subdomains share a single Load Balancer IP, keeping infrastructure costs flat.

---

## 1. Connecting to GKE (Google Kubernetes Engine) (MacOS)

1. Install `kubectl`

```bash
brew install kubectl
```

2. Install Google Cloud CLI

```bash
brew install --cask google-cloud-sdk
```

Then **restart** your terminal.

3. Authenticate

```bash
gcloud auth login
```

4. Set the default Google Cloud Project for all subsequent command run by the Google Cloud CLI (`gcloud`)

```bash
gcloud config set project artful-reactor-351917
```

5. Get GKE cluster credentials

```bash
gcloud container clusters get-credentials "essa-cluster" --region "europe-central2"
```

6. Install GKE cloud auth plugin

```bash
brew install google-cloud-sdk-gke-gcloud-auth-plugin
```

7. Exectue this command and also add it to your `.zshrc` file.

```bash
source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
```

Restart your terminal and then test the connection:

```bash
kubectl get namespaces
```

--- 

## 2. Managing the cluster

First, switch to the `essa-project` namespace by running the following command:

```bash
kubectl config set-context --current --namespace=essa-project
```

with that, `essa-project` is now your current context and you don't have to add a `-n essa-project` flag to every
kubectl command.

Right now (for development phase) everything **needs** to be deployed in this namespace. For different environments (
staging, prod) we will create namespaces later.

Why this approach:

- Logical grouping – all microservices, Secrets, ConfigMaps, and Services for the same environment live in one place
- Simpler networking – services can communicate using short DNS names
- Easier configuration management – ConfigMaps and Secrets are shared where needed
- Consistent access control – RBAC, quotas, and policies apply at the environment level
- Cleaner operations – deploy, monitor, and clean up an entire environment together

### Additional installs

We are using `Helm` to deploy application instances wherever applicable. Only standalone Kubernetes resources that are
shared by multiple microservices should be deployed via `kubectl apply` command - such as Managed certificate files,
backend configs etc...

You can install helm using Homebrew:

```bash
brew install helm
```

Verify your installation via:

```bash
helm version
```

### Creating and installing Helm charts

Its recommended to keep the same folder structure across microservice repos for easier development. Inside the main repo
directory create the following structure: `deploy/k8s/charts`.

To create a Helm chart, move into a directory where you want to create a chart (_charts directory if you follow the
above structure_) and execute the following command and replace <my-service> with your desired name:

```bash
helm create <my-service>
```

This will create the following structure:

```
my-service/
├── charts/
├── templates/ (where you put your .yaml files like service, deployment and ingress in this example)
    ├── tests  (auto generated)
    ├── service.yaml  (example by me)
    ├── deploymend.yaml (example)
    ├── ingress.yaml (example)
    ├── _helpers.tpl (auto genereated)
    ├── NOTES.txt  (useful info that is displayed in the terminal after a successful helm upgrade or helm install command)
├── .helmignore
├── Chart.yaml
├── values.yaml

```

**Key components:**

- `Chart.yaml`: Metadata about the chart
- `values.yaml`: default configuration values - those can be overriden by e.g. prod values by creating prod-values.yaml
  and then using --values command to apply them
- `templates/`: Kubernetes manifests like **deployment.yaml, service.yaml, ingress.yaml etc.**

To install your helm chart, you need to run:

```bash
helm istall my-service <path-to-chart-dir>, --values <path-to-values.yaml>
```

so something like this if i am inside `deploy/k8s/charts/` directory:

```bash
helm install my-service ./my-service --values ./my-service/values.yaml 
```

NOTE: If you didn't set essa project as your current context, you need to also add **-n essa-project** flag to install
the chart in the right namespace.

Once the chart is installed, we can still change our manifests. To apply changes we need to run:

```bash
helm upgrade my-service ./my-service --values ./my-service/values.yaml
```

If you want to apply different values file (like prod-values.yaml) you just specify the path to that file.

After that you can check if installation is working via:

```bash
kubectl get pods
kubectl get deployments
kubectl get svc
kubectl describe <resource> <resource-name>
kubectl logs <resource-name>
```

---

## GKE Subdomains & SSL Deployment guide

When deploying a new application to the cluster, you will need to create a subdomain for this service to be accessible
on the web.

Our main domain is: `myproperty-essa.com`. Any subdomains need to follow the following pattern:
`subdomain.myproperty-essa.com`.

Follow these steps to esure your new subdomain is correctly routed and secured with a **Google managed certificate**:

#### 1. Update the **Managed certificate file** `./manifests/managed-cert.yaml`.

Note: Google-managed certificates do **not** support wildcarss - each subdomain must be listed explicitly.

```yaml
apiVersion: networking.gke.io/v1
kind: ManagedCertificate```
metadata:
  name: myproperty-essa-cert
spec:
  domains:
    - myproperty-essa.com
    - keycloak.myproperty-essa.com
    - new-subdomain.myproperty-essa.com # <-- add your new domain here
```

Apply the change (make sure you are in the manifests folder or change the path):

```bash
kubectl apply -f managed-cert.yaml
```

#### 2. Update DNS records (Cloud DNS inside [Google console](https://console.cloud.google.com/net-services/dns/zones/myproperty-essa-com/details?hl=en&project=artful-reactor-351917)):

You must point the subdomain to your Load Balancer's Static IP

- Go to `Cloud DNS` and select myproperty-essa-com zone
- Below, there is a **record sets** tab with current DNS records listed
- Click `Add standard` and enter the dns name (new-subdomain prefix)
- Choose type **A record**
- Leave TTL at already filled in time (usually 5 min)
- And then under IPv4 Adress enter our static IP **35.190.18.204**  (this points `new-subdomain.myproperty-essa.com` to
  our GKE static IP 35.190.18.204)
- Click `Create`

#### 3. Match the Ingress

Update your Ingress manifest to include the new host and route it to the correct service

```yaml                                             

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: main-ingress
  annotations:
    networking.gke.io/managed-certificates: "my-managed-cert"
    kubernetes.io/ingress.class: "gce"
spec:
  rules:
    - host: new-subdomain.yourdomain.com
      http:
        paths:
          - path: /
            pathType: ImplementationSpecific
            backend:
              service:
                name: new-service-name
                port:
                  number: 80

```

Deploy the Ingress using Helm together with other resources.

#### 4. Verification and troubleshooting

**NOTE: Google validation can take 30 - 120 min**.

Use these commands and sites to check your progress and if everything is set up correctly:

**CLI Status commands**:

- `kubectl describe managedcertificate`     --> Domain Status: `Provisioning` means you need to wait, `Active` means
  success
- `kubectl describe ingress`  -->    Check Events for "Translation failed" or "Syncing" errors.
- `host <your-subdomain>` -->    Ensure it returns your Load Balancer's IP.
- `host -t AAAA <subdomain>` -->    Should return "no AAAA record".

**Useful Web Tools**:

- [DNS Checker](https://dnschecker.org/#A/keycloak.myproperty-essa.com): Input your subdomain and check if your A record
  has propagated globally
- [Google console](https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers?hl=en&project=artful-reactor-351917)
  Go under **Load balancing**, select keyclo