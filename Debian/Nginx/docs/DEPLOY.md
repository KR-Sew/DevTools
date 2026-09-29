# Deploy a Production Clone

Example:

```bash
pct clone 9001 201 --hostname proxy01 --full 1

pct set 201 \
  --cores 2 \
  --memory 1024 \
  --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=10.10.10.20/24,gw=10.10.10.1,type=veth,firewall=1

pct start 201
```

Enter it:

```bash
pct enter 201
```

## Configure a site

```bash
cp /etc/nginx/templates/reverse-proxy.conf.example \
   /etc/nginx/sites-available/example.com.conf

vim /etc/nginx/sites-available/example.com.conf
ln -s /etc/nginx/sites-available/example.com.conf /etc/nginx/sites-enabled/
nginx -t
```

Before obtaining the first certificate, either use a temporary HTTP-only vhost or let Certbot create/modify the TLS directives:

```bash
certbot --nginx -d example.com
```

Then:

```bash
nginx -t && systemctl reload nginx
proxy-check
```

## nftables

The template does not enable nftables.

Review:

```bash
cp /etc/nftables.conf.example /etc/nftables.conf
vim /etc/nftables.conf
nft -c -f /etc/nftables.conf
```

Make sure your real admin network is permitted for TCP/22 before enabling it.

Then:

```bash
systemctl enable --now nftables
nft list ruleset
```

Keep Proxmox Firewall enabled as the outer layer where appropriate.
