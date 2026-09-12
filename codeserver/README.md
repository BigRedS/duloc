# codeserver

Auth is disabled (`--auth none`) since this is only reachable over the private tailnet.

## Configuration

None

## Deploy

    kubectl apply -k .

## Storage

All on a PVC

## Non-obvious things

**No auth** — anyone with tailnet access to this hostname gets a shell/editor with your PVC's permissions. Fine for a private cluster; don't expose this Service outside Tailscale.

**`fsGroup: 1000`** is set on the pod so the mounted PVC is writable by the `coder` user the image runs as.
