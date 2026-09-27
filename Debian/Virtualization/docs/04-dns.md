# 04 — DNS and resolver configuration

Always establish working DNS before attempting package installation.

Test separately:

```bash
ping -c3 1.1.1.1
getent ahostsv4 deb.debian.org
```

If the IP test works but hostname lookup fails, investigate the resolver rather than routing.

## systemd-resolved

On Debian it may not be installed by default. Do not try to install it while DNS itself is broken.

Check:

```bash
systemctl status systemd-resolved --no-pager
ls -l /etc/resolv.conf
cat /etc/resolv.conf
```

If `systemd-resolved` is deliberately used, configure it consistently and ensure `/etc/resolv.conf` points at the intended resolver-managed file.

## Recovery principle

If `/etc/resolv.conf` is an unwritable symlink and the resolver service is absent/broken, inspect the symlink before changing anything:

```bash
readlink -f /etc/resolv.conf
ls -l /etc/resolv.conf
```

Restore temporary working name servers only after understanding who owns the file. Once DNS works, `apt` can install/repair the desired resolver stack.
