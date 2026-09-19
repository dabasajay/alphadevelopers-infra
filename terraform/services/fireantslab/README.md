# FireAnts Skills Registry

The AWS half only. Supabase, Vercel and Cloudflare serve this product too, but
they are not managed here yet — this module assumes the frontend exists
somewhere and gives it a way in that needs no AWS key.

```text
  browser ──► frontend (elsewhere) ──► presigns ──► AgentCore runtime
     │                                                   ▲
     └───────────────── direct websocket ────────────────┘
```

Playground streams never transit the frontend. It decides who may connect and
signs a short-lived URL for one session; the bytes go browser-to-runtime.

## What is here

| | |
|---|---|
| `playground_image` | One ECR repository. Both runtimes pull the same image. |
| `runtime` role | What a container runs as. Code inside can read it, so it holds nothing worth leaking. |
| `scan_runtime`, `playground_runtime` | Two runtimes. A scan is an unattended judgement that gates publication; a playground turn is someone poking at a skill. Shared compute would let one influence the other. |
| `frontend` | What the frontend may do: presign a playground websocket, and invoke or stop a runtime session. One role, because both would trust the same principal. |

## Region

The one service outside ap-south-1. Both runtimes sit in us-east-1, close to
the frontend and the database that serve them. The caller passes the region by
handing this module a provider already configured for it, so there is no second
place for it to drift.

`services/shared` names the services allowed to exist in us-east-1. Adding one
here means adding it there in the same change.

## Before the first apply

A runtime cannot be created against an empty repository, so the ECR repo is
applied on its own and given an image first. `docs/fireantslab-reconcile.md`
has the order.
