---
name: discourse-validate-security-report
description: |
  Read-only, black-box validation of a Discourse security report: reproduce the claim only through
  interfaces an attacker can actually reach, prove whether it causes real damage, and return a verdict,
  a severity opinion, and an ephemeral proof-of-concept. Use whenever someone shares a Discourse security
  report, vulnerability disclosure, or HackerOne triage — even one already bundled with a patch, CVSS
  score, or failing test — to validate, triage, or assess whether the vulnerability is real. This comes
  before any fix: sharing a report (even with a candidate patch, or asking "what do you think before I
  ship") routes here, not to code-review, test-writing, or implementation. Triggers even without the word
  "validate".
allowed-tools: read grep find ls bash
---

# discourse-validate-security-report

Decide whether a reported Discourse vulnerability is real, prove it causes actual damage, judge its
severity, and back the conclusion with evidence. Read-only (see scope below).

Start with the common checks in the [Discourse security flight manual](references/threat-model.md).
Use its routing table to open only the problem manuals needed for this report.
Work through their checks and decision gates before returning to the verdict
rules below. The same manuals guide authorized fixes and reviews. Verify each
defense against the target revision and deployment before relying on it.

## Treat Discourse as a black box

A vulnerability is real only if an attacker can trigger it through an interface Discourse exposes to a
client it does not trust. Discover what those surfaces are for the report in front of you; reason about
the exposed surface, not the implementation. If the claim only works by reaching around that surface —
through access a normal client lacks — it is not a Discourse vulnerability.

**Reproduce in dev, but judge exposure against the real deployment.** Dev can expose things a real
deployment never would. Use [`discourse_docker`](https://github.com/discourse/discourse_docker) as the
reference for what the outside world can reach — internet-facing vs. internal processes, what the reverse
proxy terminates, which ports are never published. A behavior reproducible in dev but unreachable under a
standard `discourse_docker` deployment is not valid: note the gap as a disqualifier, or `unconfirmed` if
you cannot settle it.

## Prove the damage, not just the mechanism

Reproducing the reported behavior only proves the *mechanism*: some protection is missing or bypassable.
Discourse defends in layers, so a broken protection often leaves the damage blocked by the next one. To
return `valid` you must *show* the damage, not describe it — "an attacker could take over the account" is
a claim, not proof. So before returning `valid`:

- Name the real damage, not the protection that failed.
- List every other defense between the behavior and that damage, starting from discourse_docker defaults,
  and check whether each stops it. Where the attack depends on numbers (rate, count, timing), do the math.
- Push the POC all the way to the result — account taken over, private data returned, privilege gained —
  not just to the moment a protection fails.

Lead the impact explanation with the worst credible outcome if exploited:
who could do what to whom, at what scale, and under which preconditions. Give
a concrete attack to consequence example. Distinguish demonstrated harm from
conditional, unverified escalation. Do not assume additional flaws or bypassed
defenses, or use hypothetical damage to justify the verdict or severity score.

Classify the consequence explicitly by confidentiality, integrity, and availability — never stop at a
generic label like "data disclosure". For each, state whether it is compromised and why (and if not,
why not):

- **Confidentiality:** exactly what data, whose it is, who can see it, and whether it is normally
  public / same-user / staff-only / PM content / invite-token-secret / email-IP-PII / deleted. Name the
  concrete records, fields, response bodies, or tokens received, and compare against what that attacker
  could already access — exposure matters only where it yields data they were not authorized to see.
- **Integrity:** exactly what the attacker can create, modify, delete, approve, or impersonate; whose
  state changes; whether it persists; and whether it crosses a privilege or ownership boundary.
- **Availability:** exactly what resource or function becomes unavailable, to whom, for how long, at what
  attacker cost/rate, and whether rate limits, quotas, or defaults keep it below real impact.

Damage demonstrated in a supported nondefault configuration can be `valid`.
State the configuration and how its preconditions affect exposure and severity.
Do not infer default exposure from that result. If the necessary deployment or
enforcement is unknown, use `unconfirmed`. If a verified defense blocks the
claimed path, assess any other reachable path or independent impact before
choosing `invalid` or `hardening` (see Verdicts).

## Validity is binary; preconditions drive severity

Whether a vulnerability exists is yes/no: can an attacker trigger the behavior through an exposed
interface *and* cause real damage? Required privileges and preconditions decide severity, not validity —
a vulnerability needing high privileges is still a vulnerability. Always surface the *minimum* privileges
and *every* precondition, in both the reasoning and the report. You give a well-reasoned opinion; the
user makes the final severity call.

Privileges are scoped to trust boundaries, so an administrator who can harm a neighboring tenant in a
multisite deployment is still crossing a security boundary.

## Verdicts

Return exactly one:

- **valid**: behavior reproduced through an exposed interface and real damage
  shown in the stated supported configuration. A guarantee the design depends
  on is broken. Both halves must be shown. Requires a POC.
- **invalid** — mistaken: it hits a disqualifier below, or you proved it is not exploitable through the
  exposed surface.
- **unconfirmed** — after a good-faith attempt you could neither reproduce it nor rule it out. Log what
  you tried and exactly what information from the reporter would unblock you.
- **hardening**: a real weakness (mechanism holds), but verified controls prevent
  the claimed damage in the assessed configuration and no guarantee is broken.
  The test: a fix would only tighten a limit the design already lives with, not
  restore a guarantee it depends on. Requires a POC of the mechanism, but no damage POC and no CVSS. If
  the mechanism itself is not shown, use `unconfirmed`. If the weakness is mistaken — the mechanism does
  not hold, or damage was never reachable by design — that is `invalid` instead.

**Disqualifiers (→ invalid)** — the "exploit" depends on any of:

- Bypassing the exposed interface — only works through access a normal client does not have.
- Circular privilege — the attacker must already hold the very asset (or equivalent) the attack claims to
  compromise; no real escalation or boundary crossing.
- A precondition outside Discourse — a misconfigured reverse proxy, OS, network, or the victim's own
  browser/extensions rather than Discourse's own code.
- A presupposed compromise that already grants the claimed outcome through the
  victim's session, inbox, password or 2FA device. Assess retention after
  revocation or another boundary crossing against the intended contract.

Failing to reproduce at all is `unconfirmed`, not `invalid` — unless you can affirmatively show it is
impossible through the exposed surface.

## Proof: the POC

A `valid` verdict requires a POC that goes through the exposed interface and reaches the *damage*: it must
show attacker-controlled input crossing the trust boundary via a reachable client interface (1), then the
harmful result from that input (2). A POC that only shows a protection failing proves the mechanism, not
the damage; one that starts from fabricated database state proves neither reachability nor attacker
control. Do not seed the DB, fabricate records, enqueue jobs, or call service objects as the main proof —
those may help locate a mechanism but never prove exploitability. If the damage POC relies on pre-seeded
state, separately prove the attacker can create that state through the exposed interface. If you cannot
drive it to the damage or show the state is attacker-creatable, the verdict is `unconfirmed`.

Acceptable proof, best first:

1. **System spec** — drives the real UI end to end. Strongest: reachable exactly as a user would trigger it.
2. **Request spec** — hits the actual endpoint through routing and middleware.
3. **Manual reproduction** in dev — documented, repeatable steps with observed output, when a spec is
   impractical.

Unit and isolated tests — anything invoking code directly instead of through the exposed interface — are
never acceptable proof: bypassing the routing, auth, and middleware that decide reachability cannot be
evidence of reachability.

The spec is scratch evidence, not a deliverable. Record the tree's starting state, add the throwaway spec,
run it, capture verbatim into the report its full source, exact invocation, and result — then delete the
spec and confirm the tree is clean. It is the only file you create, and it must not survive.

## Severity: CVSS v4.0

Only when the verdict is `valid` — otherwise "N/A — <verdict>". Present the metrics the report's
privileges and preconditions actually drove as a table, making each precondition's link to its metric
value explicit. The CIA analysis above drives the C/I/A metrics: assign no non-None impact unless the POC
showed the specific data exposed, state changed, or service denied. Then give the vector string, base
score, and rating. This is an opinion; the user decides.

| Metric | Value | Why — tied to the required privileges/preconditions and CIA impact |
|--------|-------|--------------------------------------------------------------------|
| … | … | … |

## Read-only scope

- Read configuration and relevant code to trace admission controls, identity,
  data flow and defenses. This does not establish exploitability by itself.
- Do not turn validation into root cause analysis or identify code to change.
- Do not propose or apply a fix.
- Do not modify application source or committed tests.
- The job ends at: verdict + justification + consequence analysis + severity opinion (CVSS only when
  valid) + POC evidence.

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
