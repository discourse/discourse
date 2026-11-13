# Discourse security flight manual

## Common checks, every report

- [ ] **Pin the target:** revision, release, plugins, site settings and deployment.
  Inspect the implementation at that revision before crediting a defense.
- [ ] **Name the actor:** minimum privilege, credential and prerequisite access.
- [ ] **List controlled inputs:** exact values, JSON types, record selectors,
  headers, metadata, remote responses, upload bytes and timing.
- [ ] **Locate the ingress:** prove the actor can reach it in the target deployment.
  A supplied record ID or claimed email does not establish ownership.
- [ ] **Choose the problem manual below.** Work its checks in order. Open another
  manual when the demonstrated path crosses its boundary, not for every report.
  Within a manual, skip checks for operations absent from the demonstrated path.
- [ ] **Record each decisive check:** observed result, source or reproduction,
  and any unknown. Do not mark an assumed defense as verified.

## Select the problem manual

| Report involves | Open | Establish before claiming impact |
| --- | --- | --- |
| Incoming email, sender attribution, DMARC or forwarding | [Email admission and identity](threat-model/email.md) | Admission through the real receiver and the identity used for the action |
| Login, signup, invites, OTPs, 2FA or revocation | [Identity and credentials](threat-model/identity.md) | Intended credential contract, verified identity and resulting access |
| PMs, groups, moderation, API scopes or private data | [Authorization and disclosure](threat-model/authorization.md) | Current permission for the exact operation, object, field and audience |
| XSS, Markdown, tags, oneboxes or rewritten content | [Rendering and transformations](threat-model/rendering.md) | Attacker supplied input reaching the final parsed output and its effect |
| SSRF, uploads, archives, native decoders or multisite | [Network, storage and isolation](threat-model/network-storage.md) | Actual destination, accessible files and effective process or tenant boundary |
| Slow requests, workers, parsers, SQL or queues | [Resource exhaustion](threat-model/resource-limits.md) | Reachable work, effective bounds and observed capacity loss |

## Deployment check, before reproducing

- [ ] Inspect the actual launcher configuration, published ports, network access,
  proxy, TLS termination and rate limits. Use the target's
  [discourse_docker](https://github.com/discourse/discourse_docker) revision and
  configuration. Check which web, database and Redis services are exposed.
  Internal listening is not public exposure.
- [ ] Reproduce through the relevant external interface. A dev server, container
  shell, database write or direct job invocation alone does not prove reachability.
- [ ] Trace the complete path, including upstream and downstream controls:

```text
actor and controlled input → ingress and admission → principal and scope
  → transformations, storage, jobs and caches → audience or operation → damage
```

## Final checks, before the verdict

- [ ] **Confidentiality:** which unauthorized records or fields reached whom?
  Compare with what the actor could already read.
- [ ] **Integrity:** what persisted, changed ownership or enabled impersonation?
- [ ] **Availability:** which service lost capacity, for how long, at what
  attacker cost and rate? Account for effective limits.
- [ ] Separate demonstrated impact from unverified escalation. A broken RCE chain
  does not erase independently demonstrated HTML injection or disclosure.
- [ ] State default versus configured exposure, verified defenses and missing
  evidence. Return to the owning skill for verdict and severity rules.
