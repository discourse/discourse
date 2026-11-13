---
name: discourse-validate-security-report
description: >
  Use when someone shares a Discourse security report, vulnerability disclosure,
  or HackerOne submission, or asks whether a suspected vulnerability is real,
  including reports with a patch or failing test.
allowed-tools: read grep find ls bash
---

# discourse-validate-security-report

Validate a reported vulnerability through an attacker accessible interface.
Return a verdict, demonstrated impact, severity opinion and ephemeral proof.

## Investigation checklist

- [ ] Start with the [security flight manual](references/threat-model.md).
  Open only relevant problem manuals and follow their checks and decision gates.
  They also guide authorized fixes and reviews.
- [ ] Pin the target revision and deployment. Verify defenses there.
- [ ] Identify minimum privileges, controlled inputs and every precondition:
  configuration, plugins, themes, data, access, timing and rate.
- [ ] Reproduce through a real client interface. Internal calls, database access
  and fabricated jobs cannot establish attacker reachability.
- [ ] Judge deployment exposure using the target's
  [discourse_docker](https://github.com/discourse/discourse_docker) configuration:
  published ports, internal services, reverse proxy and TLS termination.
  Development exposure alone is insufficient. A path unavailable in the supported
  deployment is invalid. Unknown exposure is `unconfirmed`.
- [ ] Trace every defense between input and damage. Verify enforcement and do
  the arithmetic for rate, count or timing claims.
- [ ] Drive the POC through those defenses to actual damage. A missing protection
  or suspicious mechanism alone does not establish exploitability.
- [ ] Assess independently demonstrated harm even when a later exploit step fails.
  Do not assume additional flaws or bypassed defenses.

## Impact checklist

- [ ] Lead with the worst credible outcome: who can do what to whom, at what
  scale and under which preconditions. Give a concrete attack to consequence
  example. Separate demonstrated harm from conditional, unverified escalation.
- [ ] **Confidentiality:** name the records, fields, bodies or tokens received,
  their owner and audience. Distinguish public, own, staff, PM, deleted, invite
  secrets and personal data. Compare with the actor's existing access.
- [ ] **Integrity:** name what the attacker creates, modifies, deletes, approves
  or impersonates, whose state changes, persistence and the boundary crossed.
- [ ] **Availability:** name the lost function or resource, affected users,
  duration, attacker cost and rate. Account for effective limits and quotas.
- [ ] State each CIA impact, including why an impact is absent.
- [ ] Supported nondefault configurations can be `valid`. State their prerequisites
  and severity implications without claiming default exposure.
- [ ] Privilege affects severity, not validity, unless it already grants the claimed
  outcome. Administrator access on one site does not grant access to another tenant.
  The user makes the final severity decision.

## Verdict gates

Return exactly one:

| Verdict | Required evidence |
| --- | --- |
| **valid** | Exposed interface reproduction demonstrates real damage and breaks a guarantee the design depends on. Requires a damage POC. |
| **invalid** | The claim is mistaken, disproven or meets a disqualifier below. |
| **unconfirmed** | A good faith attempt neither proved nor ruled out exploitation. Record attempts and the exact missing evidence. |
| **hardening** | The mechanism is demonstrated, verified controls prevent damage and no guarantee is broken. A fix would tighten an existing design limit. Requires a mechanism POC, no CVSS. |

- [ ] Use `invalid` when the claim requires internal access unavailable to the
  attacker, circular privilege, or misconfigured infrastructure or victim browser
  behavior outside Discourse.
- [ ] Use `invalid` when prior compromise of the victim's session, inbox, password
  or 2FA device already grants the claimed outcome. Check retention after revocation
  or any additional boundary against the intended contract.
- [ ] Failure to reproduce is `unconfirmed` unless evidence rules the path out.
- [ ] Missing mechanism proof is `unconfirmed`, not `hardening`. A mistaken
  mechanism or harm unreachable by design is `invalid`.
- [ ] When a verified defense blocks one path, assess other reachable paths and
  independent harm before deciding `invalid` or `hardening`.

## Proof checklist

- [ ] Prefer a system spec, then a request spec through routing and middleware,
  then repeatable manual reproduction with observed output when specs are impractical.
- [ ] Show attacker controlled input crossing the exposed boundary and causing
  damage. If setup uses seeded state, separately prove the attacker can create
  that state through the exposed interface.
- [ ] Unit tests, service calls, fabricated records and direct job execution are
  supporting evidence only. They bypass the controls that decide reachability.
  Unproven attacker control or damage means `unconfirmed`.
- [ ] Record the starting tree. Create no files except one scratch spec. Execute it, capture
  its full source verbatim, exact command and result, then remove it and verify
  the tree is clean. Proof is report evidence, never a committed deliverable.

## Severity checklist

- [ ] Give CVSS v4.0 only for `valid`. Otherwise write `N/A — <verdict>`.
- [ ] Tabulate each metric, value and the privilege, prerequisite or demonstrated
  CIA impact supporting it. Do not assign impact the POC did not show.
- [ ] Include the vector, base score and rating as an opinion for the user.

## Scope

- Read configuration and code to trace controls, identity and data flow.
  Source inspection alone does not prove exploitation.
- Do not identify code to change, perform root cause analysis, propose or apply
  fixes, or modify application source or committed tests.
- Stop after verdict, justification, consequence analysis, severity and POC evidence.

## Output format

```markdown
# Verdict: <valid | invalid | unconfirmed | hardening>
One short paragraph in black-box terms: which exposed interface is or isn't involved, and whether this is
an exploitable vulnerability, a mistaken claim, unproven, or hardening-only — and why.

## Attacker model
- Minimum privileges: <anonymous | regular user | moderator | admin | other> — and why.
- Preconditions: every site setting, plugin/theme, or data condition that must hold, or none.
- Exposed interface exercised: what the attacker reaches to inject the input and trigger the behavior.

## Impact / consequence
- Worst credible outcome: <concrete attack to consequence example, affected scope,
  required preconditions, and whether demonstrated or conditional and unverified>.
- Real damage: <account takeover | data disclosure | privilege escalation | ...>, or, if none under
  defaults, which case — `invalid` or `hardening` — and why.
- Confidentiality / Integrity / Availability: for each, the specifics (per the guidance above), or none
  with why.
- Other defenses between the behavior and the damage (from discourse_docker defaults) and whether each
  stops it.
- Whether the damage is reachable under default settings — with the math where numbers matter — or which
  non-default settings it needs.
- For `valid`: how the POC shows both injection through the exposed interface and the damage itself.

## Severity (CVSS v4.0)
<valid: the metric table (metric | value | why) + vector string + base score + rating.
otherwise: N/A — <verdict>.>

## POC / evidence
<valid: proof type, the full throwaway-spec source (verbatim, in a code block), exact command(s), the
captured result showing exploitability, and confirmation the tree was left clean.
invalid: the disqualifying evidence, or the demonstration it isn't exploitable through the exposed
surface — including, where the mechanism reproduced but no harm is reachable, the compensating control
(and arithmetic) that stops it.
unconfirmed: everything tried (commands + observations) and the specific information from the reporter
that would unblock validation.>
```
