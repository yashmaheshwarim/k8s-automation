# Troubleshooting Guide

## EC2 User Data not executing

Check whether the instance received the user data script and whether cloud-init ran:

```bash
sudo journalctl -u cloud-final -n 200 --no-pager
sudo cloud-init status --long
ls -l /var/log/cloud-init-output.log
```

If there are errors, confirm that the AWS EC2 instance has a public subnet and the instance is running. Also verify the user-data script in Terraform is valid shell and that the instance metadata service is reachable.

## containerd failing to start

Inspect the service and configuration:

```bash
sudo systemctl status containerd --no-pager
sudo journalctl -u containerd --no-pager -n 200
sudo containerd config dump
```

Common fixes:

- Ensure `SystemdCgroup = true` in `/etc/containerd/config.toml`
- Restart containerd: `sudo systemctl restart containerd`
- Verify the config file is valid and the service is enabled

## kubeadm init errors

Look for kubelet or control-plane failures:

```bash
sudo journalctl -u kubelet -n 200 --no-pager
sudo kubeadm reset -f
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket unix:///run/containerd/containerd.sock
```

Typical causes include:

- Swap still enabled
- Missing kernel modules or sysctl settings
- containerd not using the correct cgroup driver
- DNS or network issues during cluster bootstrap

## Swap not disabled

Check whether swap is active:

```bash
swapon --show
sudo swapoff -a
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
```

Then reboot or re-run the installation script. Kubernetes requires swap to be disabled for proper operation.

## Kubernetes node stuck in NotReady

Run:

```bash
kubectl get nodes
kubectl describe node <node-name>
kubectl get pods -A
kubectl -n kube-system get pods
```

Look for:

- Flannel issues
- containerd runtime problems
- kubelet crash loops
- cgroup or networking configuration problems

## Flannel pod stuck in CrashLoopBackOff

Check the pod and daemonset logs:

```bash
kubectl -n kube-system get pods
kubectl -n kube-system describe pod -l app=flannel
kubectl -n kube-system logs -l app=flannel --all-containers --tail=200
```

Common causes include:

- Pod CIDR mismatch
- Missing kube-config or stale cluster state
- Flannel manifest incompatible with the cluster version
- Network policy or firewall restrictions

If necessary, re-run the initialization flow after resetting kubeadm.
