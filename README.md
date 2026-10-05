# upleb.uk

> cgit theme + nav HTML for upleb.uk — public git repos served from the upleb ngit-grasp GRASP relay.

**Live**: <https://upleb.uk>

## Stack

- CSS + HTML + minimal JS
- Designed to drop into `/usr/share/cgit/` on a host running cgit + nginx + fcgiwrap
- Sister to ngit-grasp (the upleb GRASP relay backing the repos cgit serves)

## Nostr

_No Nostr events published by this site._

Pure static CSS/HTML + a one-time bootstrap shell script. Sits in front of cgit + ngit-grasp; not a build-step project.

## Develop

_No dev server — edit the CSS/HTML directly and re-deploy._

## Build + deploy

There is no deploy script: the files go to paths only root can write, root
login is off, and `sudo` asks for a password. Copy them to the deploy user's
home, then install them on the server (`upleb.uk` is an SSH host alias):

```bash
scp upleb.css upleb-header.html upleb-head-include.html favicon.ico favicon.svg cgitrc upleb.uk:
ssh -t upleb.uk 'sudo install -m 644 upleb.css upleb-header.html upleb-head-include.html favicon.ico favicon.svg /usr/share/cgit/ \
  && sudo install -m 644 cgitrc /etc/cgitrc \
  && sudo find /var/cache/cgit -mindepth 1 -delete'
```

> `cgitrc` lives at `/etc/cgitrc`, everything else at `/usr/share/cgit/`. cgit reads its files on the next request — no nginx reload needed; clear `/var/cache/cgit` so changes show immediately.

Server addresses and the nginx / SSL / DNS notes for the wider deployment live in the local `code_gh/macos-node/CLAUDE.md` (not pushed; this README is the public-facing summary).
