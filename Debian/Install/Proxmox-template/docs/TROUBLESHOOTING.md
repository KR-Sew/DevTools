# <img width="35" height="35" src="https://img.icons8.com/fluency/48/proxmox.png" alt="proxmox"/> Troubleshooting — Debian 13 NGINX Reverse Proxy on Proxmox LXC

[![Proxmox](https://img.shields.io/badge/proxmox-proxmox?style=flat&logo=proxmox&logoColor=%23E57000&labelColor=%232b2a33&color=gray)](https://learn.microsoft.com/en-us/windows/wsl/about)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

> **Case study:** Migrating `de.vezu.ru` from HTTPS on Windows Apache to HTTPS on an NGINX reverse proxy in Proxmox LXC, with Apache retained as an HTTP-only 1C application backend.
>
> **Status:** End-to-end HTTPS proxying and HTTP-to-HTTPS redirect confirmed working on 7 October 2026.

## 1. Architecture and addresses

| Component | Address | Purpose |
|---|---|---|
| Proxmox LXC | CT `201`, `10.0.0.154` | NGINX, TLS termination, Let's Encrypt |
| Windows Apache | `10.0.1.57` | HTTP-only backend serving 1C publications |
| Public/internal hostname | `de.vezu.ru` | Client-facing hostname |
| Backend URL | `http://10.0.1.57` | NGINX `proxy_pass` target |

```text
Client ── HTTPS :443 ──> de.vezu.ru / 10.0.0.154
                            NGINX (CT 201)
                                 │
                                 └── HTTP :80 ──> 10.0.1.57
                                                   Apache / 1C
```

NGINX handles the certificate and redirects port 80 to HTTPS. Apache listens only on port 80. The final DNS A record observed from the client was `de.vezu.ru -> 10.0.0.154`.

**Scope:** These addresses are from this deployment; substitute your own in other environments. If clients connect from the Internet, public DNS and NAT/firewall forwarding may differ from the internal A record shown here.

## 2. Quick health checks

Run on the **Proxmox host**:

```bash
sudo pct status 201
sudo pct exec 201 -- /usr/local/sbin/proxy-check
sudo pct exec 201 -- nginx -t
sudo pct exec 201 -- certbot certificates
sudo pct exec 201 -- systemctl status certbot.timer --no-pager
sudo pct exec 201 -- certbot renew --dry-run
sudo pct exec 201 -- cat /etc/nginx/sites-available/de.vezu.ru.conf
```

Run on a **client**:

```powershell
Resolve-DnsName de.vezu.ru
curl.exe -v https://de.vezu.ru/
curl.exe -I http://de.vezu.ru/
```

Expected after migration: DNS resolves to the proxy (`10.0.0.154`), HTTPS returns the backend's content via `Server: nginx`, and HTTP returns `301` with `Location: https://de.vezu.ru/`.

## 3. Problem: Apache fails to start with `Invalid command 'SSLEngine'`

### Symptom

```text
AH00526: Syntax error on line 31 of C:/Apache24/conf/extra/httpd-vhosts.conf
Invalid command 'SSLEngine', perhaps misspelled or defined by a module not included in the server configuration
```

### Root cause

The main Apache config had SSL disabled:

```apache
Listen 80
#Listen 443
#LoadModule ssl_module modules/mod_ssl.so
#Include conf/extra/httpd-ssl.conf
```

But `httpd.conf` **still included** `conf/extra/httpd-vhosts.conf`, which initially contained an active `SSLEngine On` directive in an HTTPS virtual host. Disabling the SSL module alone is insufficient while active SSL directives remain elsewhere.

### Resolution used

In `C:\Apache24\conf\extra\httpd-vhosts.conf`, comment out the **entire obsolete `*:443` virtual host**, including `SSLEngine`, certificate paths, and closing tag. Preserve unrelated HTTP configuration. Do **not** re-enable SSL just to silence this error when the intended architecture is HTTP-only Apache behind NGINX.

```powershell
C:\Apache24\bin\httpd.exe -t
```

Confirmed result:

```text
Syntax OK
```

Restart Apache only after the syntax check passes:

```powershell
Restart-Service Apache2.4
```

If the service has a different name, find it with `Get-Service *apache*`.

## 4. Warning: `AH00671` overlapping Apache Alias

### Symptom

```text
[alias:warn] AH00671: The Alias directive in C:/Apache24/conf/httpd.conf
at line 720 will probably never match because it overlaps an earlier Alias.
```

### Cause

Two entries used the same URL path:

```apache
Alias "/orders" "C:/wwwpub/orders/"
# ... later ...
Alias "/orders" "C:/wwwpub/uservice/"
```

The later mapping is shadowed by the earlier mapping. This was a **warning**, not the SSL startup failure; `httpd.exe -t` still returned `Syntax OK`.

### Recommended follow-up

Determine which 1C publication should own `/orders` before removing or renaming either Alias. **This duplicate Alias was identified but not corrected during the TLS migration.**

## 5. Problem: HTTPS works on NGINX but returns `301` instead of application content

### Symptom

Forced proxy test:

```bash
curl -vk --resolve de.vezu.ru:443:10.0.0.154 https://de.vezu.ru/
```

Returned:

```text
HTTP/1.1 301 Moved Permanently
Server: nginx
Location: https://de.vezu.ru
```

### Root cause

Apache still had an HTTP virtual host that redirected all requests to the public HTTPS hostname:

```apache
<VirtualHost *:80>
    ServerName de.vezu.ru
    Redirect permanent / https://de.vezu.ru
</VirtualHost>
```

The resulting path was:

```text
Client HTTPS -> NGINX -> Apache HTTP -> 301 to same public HTTPS URL -> repeat
```

`Server: nginx` alone does **not** prove the redirect originated in NGINX; NGINX can forward an upstream Apache response.

### Resolution used

Comment out or remove the redirect-only `*:80` vhost in `C:\Apache24\conf\extra\httpd-vhosts.conf`. The 1C publication aliases remained in the main Apache config.

```powershell
C:\Apache24\bin\httpd.exe -t
Restart-Service Apache2.4
curl.exe -I http://10.0.1.57
```

Confirmed backend response:

```text
HTTP/1.1 200 OK
Server: Apache/2.4.38 (Win64)
Content-Length: 46
```

Confirmed proxy response:

```text
HTTP/1.1 200 OK
Server: nginx
Content-Length: 46

<html><body><h1>It works!</h1></body></html>
```

The matching content length, `Last-Modified`, and ETag corroborated that NGINX returned the Apache backend content.

## 6. Problem: DNS bypasses the reverse proxy

### Symptom

Initially, `de.vezu.ru` resolved to the **backend** address `10.0.1.57`. A normal HTTPS request reached the old Apache TLS endpoint and showed an older **RSA** certificate, despite the new NGINX certificate being present.

### Diagnosis

```powershell
Resolve-DnsName de.vezu.ru
```

Force a request to the intended proxy without changing DNS:

```bash
curl -vk --resolve de.vezu.ru:443:10.0.0.154 https://de.vezu.ru/
```

This preserves the hostname for HTTP Host and TLS SNI while connecting directly to the specified IP.

### Resolution used

The internal DNS A record was changed:

```text
BEFORE: de.vezu.ru -> 10.0.1.57  (Apache; bypasses NGINX)
AFTER:  de.vezu.ru -> 10.0.0.154 (NGINX CT 201)
```

On Windows, if needed:

```powershell
Clear-DnsClientCache
Resolve-DnsName de.vezu.ru
curl.exe -v https://de.vezu.ru/
curl.exe -I http://de.vezu.ru/
```

**Confirmed final results:**

- DNS resolved `de.vezu.ru` to `10.0.0.154`.
- HTTPS returned `200 OK`, `Server: nginx`, and the Apache `It works!` page.
- HTTP returned `301 Moved Permanently`, `Server: nginx`, and `Location: https://de.vezu.ru/`.

**Deployment-script improvement:** Warn if the hostname resolves directly to the backend IP. In environments with NAT, split DNS, or public load balancers, the DNS result need not literally equal the LXC private IP; compare against the expected entry point rather than treating every mismatch as a failure.

## 7. Confirm Apache is HTTP-only

On the Windows Apache server:

```powershell
Get-NetTCPConnection -State Listen |
    Where-Object LocalPort -in 80,443 |
    Format-Table LocalAddress,LocalPort,OwningProcess -AutoSize

C:\Apache24\bin\httpd.exe -S
```

Confirmed listeners:

```text
LocalAddress LocalPort OwningProcess
------------ --------- -------------
::                  80          2948
0.0.0.0             80          2948
```

Confirmed virtual host:

```text
*:80 de.vezu.ru (C:/Apache24/conf/extra/httpd-vhosts.conf:24)
```

And from a client:

```powershell
curl.exe -I http://10.0.1.57
curl.exe -kI https://10.0.1.57
```

HTTP returned `200 OK`; HTTPS failed to connect to port 443. The old certificate files were **not required to be deleted** to disable HTTPS. Keep them until you have verified no other service depends on them.

## 8. Verify the Let's Encrypt certificate on NGINX

From the Proxmox host:

```bash
sudo pct exec 201 -- certbot certificates
sudo pct exec 201 -- systemctl status certbot.timer --no-pager
sudo pct exec 201 -- certbot renew --dry-run
```

Confirmed for `de.vezu.ru`:

```text
Certificate: /etc/letsencrypt/live/de.vezu.ru/fullchain.pem
Private key: /etc/letsencrypt/live/de.vezu.ru/privkey.pem
Key type: ECDSA
Expires: 2027-01-05 11:53:02 UTC
```

`certbot.timer` was enabled/active and the renewal dry run succeeded.

Force a TLS request to the proxy:

```bash
curl -v --resolve de.vezu.ru:443:10.0.0.154 https://de.vezu.ru/
```

Prefer testing **without `-k`** for certificate-chain validation. The earlier diagnostic used `-k`, so its `unable to get local issuer certificate` warning was **not** a successful certificate-trust check. Later Windows `curl.exe -v` without `-k` completed successfully through Schannel, but no separate full chain audit was recorded.

## 9. Recommended `add-proxy-host.sh` final checks

After writing the NGINX HTTPS vhost, test two independent paths:

**A. Forced local NGINX test** — works even before DNS migration:

```bash
sudo pct exec 201 -- \
  curl -ksS \
  --resolve de.vezu.ru:443:127.0.0.1 \
  -o /dev/null -w '%{http_code}\n' \
  https://de.vezu.ru/
```

This validates the selected NGINX HTTPS virtual host and HTTP exchange with the backend. Because `-k` disables verification, it does **not** establish certificate trust. An HTTP response code is useful evidence of reachability but does not by itself prove the application is healthy; inspect unexpected `301`, `502`, `503`, or `504` responses.

**B. Real DNS/client-path test** — after DNS points to the proxy:

```bash
curl -I http://de.vezu.ru/
curl -v https://de.vezu.ru/
```

Expected in this deployment: HTTP `301` to HTTPS; HTTPS `200` through NGINX. Other backends may legitimately return `302`, `401`, `403`, or another application-specific status.

**Important:** During an initial deployment, real-DNS tests may still hit the old backend. Report that as a warning rather than automatically failing an otherwise valid local NGINX configuration. Conversely, do not print an unconditional end-to-end success message if only the local test passed.

## 10. Application-level testing still required

The confirmed `200 OK` was for `/`, which returned Apache's default `It works!` page. It did **not** prove that every 1C publication was working.

Test real endpoints used by clients, for example:

```powershell
curl.exe -I https://de.vezu.ru/corp/
curl.exe -I https://de.vezu.ru/vezu/
```

A `HEAD` request may not be supported by every application. Where needed, use a browser or a regular GET request and validate login, sessions, uploads, callbacks, and application-generated redirects. These application tests were **recommended but not recorded as completed** in the conversation.

## 11. Common status codes and next checks

| Observation | Likely area to investigate | First check |
|---|---|---|
| Apache `Invalid command 'SSLEngine'` | SSL directive active while `mod_ssl` disabled | `httpd.exe -t`, inspect `httpd-vhosts.conf` |
| `AH00671` warning | Overlapping Apache aliases | Search for duplicate `Alias` paths |
| HTTPS repeatedly returns `301` to same URL | Backend HTTP-to-HTTPS redirect loop | `curl -I http://BACKEND_IP` |
| Old certificate appears | DNS/NAT routes to old TLS endpoint | `Resolve-DnsName`, `curl --resolve` |
| `502 Bad Gateway` | NGINX cannot get valid response from upstream | NGINX error log, backend connectivity |
| `504 Gateway Timeout` | Backend response/connect timeout | Backend health and NGINX error log |
| HTTPS certificate warning | Chain/trust/SNI issue | Retry without `-k`; inspect full chain |
| Root URL works but 1C app fails | Application publication/configuration | Test actual 1C URL and Apache logs |

Useful NGINX logs inside CT:

```bash
sudo pct exec 201 -- tail -n 100 /var/log/nginx/de.vezu.ru.error.log
sudo pct exec 201 -- tail -n 100 /var/log/nginx/de.vezu.ru.access.log
```

## 12. Security and operational follow-up

- Restrict backend port `10.0.1.57:80` to the reverse proxy and required administration/monitoring networks **after** checking for other legitimate consumers of the many 1C publications.
- Keep the backend certificate files until dependencies have been checked; disabling the HTTPS listener was sufficient for this migration.
- Review the duplicate `/orders` Apache Alias separately.
- Confirm the real 1C application endpoints, not only Apache's default page.
- Preserve Certbot renewals and validate renewal after major NGINX configuration changes.
- Consider monitoring certificate expiration and proxy availability.
- Use a temporary hostname to test `remove-proxy-host.sh` before touching the working `de.vezu.ru` vhost.

## 13. Final migration checklist

- [x] Apache syntax validation: `Syntax OK`
- [x] Apache HTTPS vhost and SSL listener disabled
- [x] Apache HTTP backend returns `200 OK`
- [x] Removed Apache HTTP-to-HTTPS redirect loop
- [x] NGINX serves new ECDSA Let's Encrypt certificate
- [x] Certbot timer active; renewal dry run successful
- [x] Forced `--resolve` test through NGINX returns backend content
- [x] DNS points `de.vezu.ru` to NGINX (`10.0.0.154`)
- [x] Normal HTTPS client request returns `200 OK` via NGINX
- [x] Normal HTTP client request redirects to HTTPS (`301`)
- [ ] Test representative production 1C publications and workflows
- [ ] Review/remove duplicate `/orders` Alias
- [ ] Apply backend firewall restrictions after dependency review
- [ ] Exercise proxy-host removal workflow on a disposable hostname

---

**Related repo utilities:** `deploy-proxy.sh`, `scripts/add-proxy-host.sh`, `scripts/list-proxy-hosts.sh`, `scripts/remove-proxy-host.sh`, and `/usr/local/sbin/proxy-check`.
