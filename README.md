## Welcome

We're really happy that you're considering joining us!
This challenge will help us understand your skills and will also be a starting point for the next interview.
We're not expecting everything to be done perfectly as we value your time but the more you share with us, the more we get to know about you!

This challenge is split into 3 parts:

1. Debugging
2. Implementation
3. Questions

If you find possible improvements to be done to this challenge please let us know in this readme and/or during the interview.

## The challenge

Pleo runs most of its infrastructure in Kubernetes.
It's a bunch of microservices talking to each other and performing various tasks like verifying card transactions, moving money around, paying invoices, etc.
This challenge is similar but (a lot) smaller :D

In this repo, we provide you with:

- `invoice-app/`: An application that gets invoices from a DB, along with its minimal `deployment.yaml`
- `payment-provider/`: An application that pays invoices, along with its minimal `deployment.yaml`
- `Makefile`: A file to organize commands.
- `deploy.sh`: A file to script your solution
- `test.sh`: A file to perform tests against your solution.

### Set up the challenge env

1. Fork this repository
2. Create a new branch for you to work with.
3. Install any local K8s cluster (ex: Minikube) on your machine and document your setup so we can run your solution.

### Part 1 - Fix the issue

The setup we provide has a :bug:. Find it and fix it! You'll know you have fixed it when the state of the pods in the namespace looks similar to this:

```
NAME                                READY   STATUS                       RESTARTS   AGE
invoice-app-jklmno6789-44cd1        1/1     Ready                        0          10m
invoice-app-jklmno6789-67cd5        1/1     Ready                        0          10m
invoice-app-jklmno6789-12cd3        1/1     Ready                        0          10m
payment-provider-abcdef1234-23b21   1/1     Ready                        0          10m
payment-provider-abcdef1234-11b28   1/1     Ready                        0          10m
payment-provider-abcdef1234-1ab25   1/1     Ready                        0          10m
```

#### Requirements

Write here about the :bug:, the fix, how you found it, and anything else you want to share.

#### Solving

I am using minikube for a quick and generic testing environment.

##### Creating the images

Images are not public images so I want to build them locally and then deploy using the provided deployment.yaml

```
docker build -t invoice-app:latest -f invoice-app/Dockerfile invoice-app/
docker build -t payment-provider:latest -f payment-provider/Dockerfile payment-provider/
kubectl apply -f invoice-app/deployment.yaml
```

I then find myself with a ErrImagePull error.

```
NAMESPACE              NAME                                         READY   STATUS             RESTARTS      AGE
default                invoice-app-779bb6f9d5-9744d                 0/1     ErrImagePull       0             2m34s
default                invoice-app-779bb6f9d5-pmgkw                 0/1     ImagePullBackOff   0             2m34s
default                invoice-app-779bb6f9d5-zkp5j                 0/1     ErrImagePull       0             2m34s
```

This is due to the fact that minikube runs its own local repository and images must be built against it.

```
eval $(minikube -p minikube docker-env)
docker build -t invoice-app:latest -f invoice-app/Dockerfile invoice-app/
docker build -t payment-provider:latest -f payment-provider/Dockerfile payment-provider/
kubectl apply -f invoice-app/deployment.yaml
```

We still have an error which is this time CreateContainerConfigError, which must be the :bug: we are looking for. A quick lookup at one of the containers tells us more:

```
kubectl describe pod invoice-app-779bb6f9d5-4qp7t | sed '/^Events:/,$!d'
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  16s               default-scheduler  Successfully assigned default/invoice-app-779bb6f9d5-4qp7t to minikube
  Normal   Pulled     2s (x3 over 16s)  kubelet            Container image "invoice-app:latest" already present on machine
  Warning  Failed     2s (x3 over 16s)  kubelet            Error: container has runAsNonRoot and image will run as root (pod: "invoice-app-779bb6f9d5-4qp7t_default(0da2e457-0e41-4df7-a3df-8950d6a4a06e)", container: main)
```

In the deployment.yaml we indeed have runAsNonRoot which is configured, but not what user to use instead of root. We could remove the runAsNonRoot configuration but we should avoid running container as root. We add a `runAsUser: 1042` directive in the securityContext to run as an arbitrary user and fix the issue. The same configuration is done in both invoice-app and payment-method. We apply again and the pods are running.

```
kubectl apply -f invoice-app/deployment.yaml
kubectl apply -f payment-provider/deployment.yaml
kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
invoice-app-78f496966f-5h6h2        1/1     Running   0          36s
invoice-app-78f496966f-fctpp        1/1     Running   0          34s
invoice-app-78f496966f-qvx6f        1/1     Running   0          33s
payment-provider-556d674db9-8f9mp   1/1     Running   0          18s
payment-provider-556d674db9-fvt7s   1/1     Running   0          18s
payment-provider-556d674db9-q7fw8   1/1     Running   0          18s
```

### Part 2 - Setup the apps

We would like these 2 apps, `invoice-app` and `payment-provider`, to run in a K8s cluster and this is where you come in!

#### Requirements

1. `invoice-app` must be reachable from outside the cluster.
2. `payment-provider` must be only reachable from inside the cluster.
3. Update existing `deployment.yaml` files to follow k8s best practices. Feel free to remove existing files, recreate them, and/or introduce different technologies. Follow best practices for any other resources you decide to create.
4. Provide a better way to pass the URL in `invoice-app/main.go` - it's hardcoded at the moment
5. Complete `deploy.sh` in order to automate all the steps needed to have both apps running in a K8s cluster.
6. Complete `test.sh` so we can validate your solution can successfully pay all the unpaid invoices and return a list of all the paid invoices.

#### Solving

##### invoice-app and payment-provider access (points 1 & 2)

In order to make invoice-app accessible from outside the cluster and not payment-provider, we will use two differents kinds of services: NodePort for invoice-app and ClusterIP for payment-provider.

Here is a test of this configuration:

```
kubectl apply -f invoice-app/service.yaml
kubectl apply -f payment-provider/service.yaml
minikube service invoice-app --url
http://192.168.49.2:30738
curl http://192.168.49.2:30738
404 page not found
curl http://192.168.49.2:30738/invoices
[{"InvoiceId":"I1","Value":12.15,"Currency":"EUR","IsPaid":false},{"InvoiceId":"I2","Value":10.25,"Currency":"GBP","IsPaid":false},{"InvoiceId":"I3","Value":66.13,"Currency":"DKK","IsPaid":false}]
minikube service payment-provider --url
😿  service default/payment-provider has no node port

```

##### Best practices (point 3)

The following points are implemented:

- liveness probe
- resource limits
- set labels
- improve securityContext

##### pass backend URL to frontend (point 4)

We can use a configMap to pass invoice-app the URL it can access payment-provider with. The go program of invoice-app must then be changed to use the environment variable.

##### deployment script (point 5)

`deploy.sh` is completed. When ran without any option, it starts minikube if needed and applies configuration. There are two option --force (or -f) to destroy all components prior to application and --destroy (or -d) to destroy and exit.

### Part 3 - Questions

Feel free to express your thoughts and share your experiences with real-world examples you worked with in the past.

#### Requirements

1. What would you do to improve this setup and make it "production ready"?
2. There are 2 microservices that are maintained by 2 different teams. Each team should have access only to their service inside the cluster. How would you approach this?
3. How would you prevent other services running in the cluster to communicate to `payment-provider`?

## What matters to us?

We expect the solution to run but we also want to know how you work and what matters to you as an engineer.
Feel free to use any technology you want! You can create new files, refactor, rename, etc.

Ideally, we'd like to see your progression through commits, verbosity in your answers and all requirements met.
Don't forget to update the README.md to explain your thought process.
