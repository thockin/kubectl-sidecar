# kubectl-sidecar

This repo has all the base tools to build a kubectl "sidecar" container.

## Why would I want this?

Often a Kubernetes Pod wants to know something about itself or its environment.
Kubernetes offers a "downward API" which can publish some information via
environment variables or files.  This information is very limited in scope and
not very flexible in formatting.  It's not uncommon to need information that
isn't offered or to need it formatted in some particular way.

Instead of asking Kubelet to fetch the data, which poses a risk of violating
authorization policies and exposing information that should not be exposed, and
instead of teaching kubelet to do arbitrary formatting and template expansion,
this project offers a different approach.

Do it yourself!

Only the author of a Pod can really know what information they need or how they
want it formatted.  Perhaps more important than that, we already have a nice
mechanism for controlling what information a given Pod is allowed to know - the
kube-apiserver's configured authorization policies (e.g. RBAC).  If the pod
itself requests the information it needs, the cluster administrators can decide
if that level of information is allowed.

That said, it's unreasonable to change arbitrary apps to become Kubernetes
clients.  Fortunately, this is exactly what sidecar containers are good for.  A
Pod can run an additional container whose job is to fetch information from the
API, format it, and write it to a shared volume.  The main app can consume the
information from the volume.

## How to use this

This repo offers an example of how you might build such a sidecar.  Only you
know which data processing and formatting tools you need, and where your app is
allowed to pull images from.  Including too much in a container can pose
security risks.  Including too little makes it not useful.  You are best
positioned to make those tradeoffs.

## Example

Here is a working [example](example.yaml) which you can use to understand this
approach. After applying the manifest you can check it using:

```
kubectl port-forward deployment/demo-kubectl-sidecar 8080:80
curl http://localhost:8080/this-pod-status.json
curl http://localhost:8080/this-node-status.json
```
