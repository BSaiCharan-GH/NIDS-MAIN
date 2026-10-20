# NIDS-MAIN — Render deployment guide

## Hosted version

This deploys the existing Flask + Socket.IO NIDS project, keeping its role-based UI, monitor, incident workflow, bundled CICIDS Random Forest and DNS-tunneling Random Forest, existing explanation code, and health endpoints.

The public hosted version runs in a safety-first portfolio mode:

- Live packet capture is disabled. A public cloud host cannot capture packets from a recruiter's laptop through Scapy/Npcap.
- DoS, PortScan, and DNS test traffic generation are disabled at both UI and server/API layers.
- File relay is disabled in public demo mode; messages are visible to connected visitors.
- Sessions, alerts, and incidents are in-memory and reset on restart. The monitor uses the checked-in `results/evaluation.json` report in hosted mode instead of rescanning the large training CSVs on app startup.
- For a real live-packet demonstration, run the project locally on an authorized private LAN with Npcap/Scapy installed.

## Deploy

1. Run `publish_nids_render.ps1` from this deployment bundle and wait for `GitHub sync succeeded.`
2. Open <https://dashboard.render.com/> and sign in.
3. Choose **New → Blueprint** and select `BSaiCharan-GH/NIDS-MAIN` (branch `main`). Render should discover `render.yaml`.
4. Confirm the service named `nids-main-demo`, then create/deploy it.
5. Wait for the build and `/ready` health check to pass.
6. Open the assigned `https://...onrender.com` URL. Free instances can take additional time on the first request after inactivity.

The deployment pins Python 3.11.11 and scikit-learn 1.8.0, matching the version recorded in the bundled DNS model metadata. It uses Gunicorn's threaded worker and `simple-websocket` for Flask-SocketIO. Existing model files are already in the repository; deployment does not retrain them.

## Smoke test

- `/` — landing page should load and display the hosted-demo notice.
- `/ready` — should return `{"ready": true}`.
- `/health` and `/api/v1/model` — inspect model status and loaded feature metadata.
- `/monitor` — dashboard assets should load; no live packet events are expected on Render.
- `/attacker/login` — the UI should say live tests are disabled in hosted mode.

## Troubleshooting

- Check the last 30–50 Render log lines if the build fails.
- If `/ready` fails, inspect startup logs for model-pickle errors.
- If Socket.IO fails to connect, check that the service uses the provided Gunicorn `gthread` command and installed `simple-websocket` dependency.
- Do not expose the local NIDS server to the public internet with packet generation enabled.
