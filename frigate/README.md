# frigate

Frigate NVR with a Coral USB TPU. Exposed via Tailscale and a MetalLB address on the LAN. Managed with Kustomize.

## Prerequisites

- Coral USB TPU plugged into the node Frigate is scheduled on, visible at `/dev/bus/usb`
- Longhorn (or another StorageClass) for the recordings PVC
- MQTT on Home-Assistant

## Configuration

`credentials.env` is gitignored and must be created from `credentials.env.example` before deploying:

`credentials.env`:
- `FRIGATE_MQTT_USER` — MQTT username
- `FRIGATE_MQTT_PASSWORD` — MQTT password
- `FRIGATE_RTSP_USER` / `FRIGATE_RTSP_PASSWORD` — same username and password on all cameras

## Deploy

```
kubectl apply -k .
```

## Non-obvious things:

- The Coral device genuinely Just Works but the container needs `privileged: true` in order to access it
