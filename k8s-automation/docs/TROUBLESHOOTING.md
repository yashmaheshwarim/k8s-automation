# Troubleshooting Guide

## EC2 User Data not executing

Check whether the instance received the user data script and whether cloud-init ran:

```bash
sudo journalctl -u cloud-final -n 200 --no-pager
sudo cloud-init status --long
ls -l /var/log/cloud-init-output.log
```

If there are errors, confirm that the AWS EC2 instance has a public subnet and the instance is running. Also verify the user-data script in Terraform is valid shell and that the instance metadata service is reachable.

## Bootstrap log and status

All bootstrap output is appended to `/var/log/k8s-install.log`:

```bash
sudo tail -n 200 /var/log/k8s-install.log
cat /var/lib/k8s-automation/status
```

The status file contains `install-complete` after Docker/kubectl/kind are installed and `cluster-ready` after the kind cluster passes its checks.

## Docker fails to install or start

```bash
sudo systemctl status docker --no-pager
sudo journalctl -u docker --no-pager -n 200
sudo docker info
```

Common fixes:

- Confirm the Docker apt repository was added: `cat /etc/apt/sources.list.d/docker.list`
- Check disk space: `df -h /`
- Restart Docker: `sudo systemctl restart docker`

If Docker cannot start because the instance ran out of disk, grow the root volume with a larger `root_volume_size` and re-apply.

## kind create cluster fails

Inspect kind and the bootstrap logs:

```bash
kind version
sudo tail -n 200 /var/log/k8s-install.log
docker ps -a
kind get clusters
```

Typical causes:

- Docker daemon not running
- Not enough memory: `t3.micro` has 1 GiB, so the 2 GB swap file must exist (`swapon --show`)
- Image pull failures caused by DNS or outbound network issues
- A previous failed cluster container still exists

To retry from scratch:

```bash
kind delete cluster --name k8s-lab
sudo /opt/k8s-automation/initialize-cluster.sh
```

## kind node stuck in NotReady

```bash
kubectl get nodes
kubectl describe node k8s-lab-control-plane
kubectl get pods -A
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=200
```

Look for:

- kindnet or CoreDNS pods crash looping
- Docker container for the node restarting (`docker ps -a`)
- Memory pressure on the host (`free -h`, `dmesg | tail`)

## API server unreachable from your machine

The API is served on port 6443 and the certificate includes the instance public IP captured at boot.

```bash
curl -k https://<EC2_PUBLIC_IP>:6443/healthz
```

Check:

- `kubernetes_api_cidr` includes your current public IP
- The security group allows TCP 6443 from that CIDR
- The instance public IP has not changed since boot (stop/start behavior). If it changed, delete and recreate the cluster so the certificate matches, or attach an Elastic IP.

## Swap not active

```bash
swapon --show
sudo swapon /swapfile
```

The bootstrap adds `/swapfile` to `/etc/fstab`, so it is restored after reboot. Kubernetes runs inside the kind container, so host swap does not break kubelet requirements.
