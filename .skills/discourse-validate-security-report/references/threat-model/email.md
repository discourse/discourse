# Email admission and identity

Use for incoming mail, DMARC, sender substitution or forwarding.

## 1. Establish submission control

- [ ] Identify SMTP delivery, mailbox polling or API ingestion.
- [ ] Separate message control from trusted API caller control. Trace submission
  authentication.
- [ ] Pin receiver version, image, settings and Rails ingress.

## 2. Verify upstream admission

- [ ] Locate SPF, DKIM and DMARC evaluation and rejection or review enforcement.
  An enabled verifier does not prove rejection.
- [ ] Check failure, unknown and verifier error policies. For
  [mail-receiver](https://github.com/discourse/mail-receiver), inspect deployed
  configuration and startup overrides, including applicable `RejectFailures`
  and `milter_default_action` behavior.
- [ ] Verify result provenance: generating service, trusted `authserv-id`, forged
  or duplicate header handling and authenticated identity. Injected headers prove none.
- [ ] When admission decides the claim, exercise the real receiver. Record
  rejection, deferral, delivery or review.
- [ ] Trace target Rails handling of trusted DMARC failure, missing trust
  configuration and unknown results through acceptance, rejection, review and
  immediate commands.

## 3. Follow identity after admission

- [ ] Compare authenticated identity with account selection for posting, forwarding,
  replies and immediate commands. Domain alignment does not prove mailbox ownership.
- [ ] Check identity changes through parsing or sender substitution.
- [ ] Follow accepted input to content, participant or account effects. Open
  [Identity](identity.md) or [Authorization](authorization.md) for crossed boundaries.

## Decision gate

- **Verified rejection:** credit the enforced defense on this path. Isolated
  downstream failure does not prove exploitation.
- **Unknown enforcement or provenance:** use `unconfirmed`. Setting names and
  injected `dmarc=pass` are not guarantees.
- **Admitted input:** follow downstream controls to damage.
- **Alternate ingress, bypass, later identity change or independent harm:** assess
  separately. Do not dismiss all email bugs.
