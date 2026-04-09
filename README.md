# viz-drupal

Local Drupal development environment. Multiple independent sites, each on its own port with its own SQLite database. No cloud dependencies, no reverse proxy.

## Requirements

- [Podman](https://podman.io/) (or Docker)
- [just](https://just.systems/)

## Quickstart

```sh
just new        # creates 'default' site on port 8001
just up         # starts it
# visit http://localhost:8001 and complete the one-time installer
# — choose SQLite, accept the default database path, press Continue
```

## Commands

```sh
just new [name]   # create a new site (name defaults to 'default')
just list         # list sites and their URLs
just up [name]    # start a site in the foreground (Ctrl+C stops and removes it)
just down [name]  # remove a leftover container (if a run didn't clean up)
just logs [name]  # tail logs for a running site (name defaults to 'default')
just build        # pull latest image
just erase <name> # delete a site's data (prompts for confirmation)
just erase-all    # delete all sites and data (prompts for confirmation)
```

Multiple sites each get their own port, auto-assigned from 8001:

```
just new mysite
just new client
just list
  mysite → http://localhost:8001
  client → http://localhost:8002
```

## Persistence

Each site's data lives in `sites/<name>/` (gitignored):

| Path                        | Contents                         |
|-----------------------------|----------------------------------|
| `sites/<name>/files/`       | SQLite database + uploaded files |
| `sites/<name>/settings.php` | Drupal configuration             |
| `sites/<name>/port`         | Assigned port number             |

Data survives `just down` / `just up`. To wipe and start fresh:

```sh
just erase mysite
just new mysite
```
