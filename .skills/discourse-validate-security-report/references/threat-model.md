# Discourse security flight manual

## Common checks

- [ ] **Pin target:** revision, release, plugins, settings and deployment.
  Verify defenses against that implementation.
- [ ] **Name actor:** minimum privilege, credentials and prerequisite access.
- [ ] **List controlled inputs:** values, JSON types, selectors, headers, metadata,
  remote responses, bytes and timing.
- [ ] **Locate ingress:** prove deployed reachability. Supplied IDs or claimed
  emails do not establish ownership.
- [ ] **Select manuals below.** Work checks in order. Open another manual only
  when the path crosses its boundary. Skip absent operations.
- [ ] **Record decisive checks:** observation, source or reproduction and unknowns.
  Assumptions are not verified defenses.

## Select the problem manual

| Report involves | Open | Establish before claiming impact |
| --- | --- | --- |
| Incoming email, sender attribution, DMARC or forwarding | [Email admission and identity](threat-model/email.md) | Real receiver admission and action identity |
| Login, signup, invites, OTPs, 2FA or revocation | [Identity and credentials](threat-model/identity.md) | Credential contract, verified identity and access |
| PMs, groups, moderation, API scopes or private data | [Authorization and disclosure](threat-model/authorization.md) | Current operation, object, field and audience permission |
| XSS, Markdown, tags, oneboxes or rewritten content | [Rendering and transformations](threat-model/rendering.md) | Controlled input, final parsed output and effect |
| SSRF, uploads, archives, native decoders or multisite | [Network, storage and isolation](threat-model/network-storage.md) | Actual destination, files and process or tenant boundary |
| Slow requests, workers, parsers, SQL or queues | [Resource exhaustion](threat-model/resource-limits.md) | Reachable work, enforced bounds and capacity loss |

## Deployment, before reproduction

- [ ] Inspect launcher, ports, network, proxy, TLS and rate limits at the target's
  [discourse_docker](https://github.com/discourse/discourse_docker) revision and
  configuration. Check web, database and Redis exposure. Listening internally
  does not establish public access.
- [ ] Reproduce through the external interface. Development servers, shells,
  database writes and direct jobs alone cannot establish reachability.
- [ ] Trace upstream and downstream controls through the complete path:

```text
controlled input → ingress and admission → principal and scope
  → transformations, storage, jobs and caches → audience or operation → damage
```

## Before the verdict

- [ ] **Confidentiality:** unauthorized records or fields, recipient and prior access.
- [ ] **Integrity:** persisted changes, ownership or impersonation.
- [ ] **Availability:** lost capacity, duration, attacker cost and rate after limits.
- [ ] Separate demonstrated harm from speculative escalation. A failed RCE chain
  does not erase proven HTML injection or disclosure.
- [ ] State default or configured exposure, verified defenses and missing evidence.
  Return to the skill for verdict and severity rules.
