# ansible

Configures `srv1136595.hstgr.cloud` as the shared datastore host: one Postgres
database and role per app, one Redis container per app, reached from Lambda over
the public internet through pgbouncer.

Run from your machine only, and only while connected to the NordVPN dedicated
IP — the Hostinger panel firewall pins SSH to that address.

```sh
cd ansible
ansible-playbook site.yml                          # everything
ansible-playbook site.yml --tags pki                # reissue certificates
ansible-playbook site.yml -e pg_rotate_passwords=true  # rotate db passwords
```

`ansible/out/` holds generated passwords, the pgBackRest passphrase, and one
`<app>.env` per app to paste into the Lambda console. It is gitignored; nothing
in it exists anywhere else, so back it up before you lose the machine.

## Adding an app

Add an entry to `group_vars/all.yml` and rerun. Its database, role, client
certificate and Redis container follow. Open the new Redis port in the Hostinger
panel firewall.

## Ports

| Port | Source | Purpose |
|---|---|---|
| 22 | admin IP only | SSH, restricted in the Hostinger panel |
| 24312 | anywhere | pgbouncer; mTLS rejects anything without a client cert |
| 24320+ | anywhere | one Redis per app, TLS plus ACL password |

Postgres publishes no host port. It is reachable only via `docker exec` after
SSH, which is why there is no `5432` row above.
