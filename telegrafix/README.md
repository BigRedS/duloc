# Telegrafix: Telegraf checks for Coralogix

See https://github.com/BigRedS/telegrafix

In the `coralogix` ns so it can use the secret

## Apply

```bash
kubectl apply -k . && kubectl -n coralogix rollout restart deployment/telegrafix
```
No hot-reload, always roll the deploy
