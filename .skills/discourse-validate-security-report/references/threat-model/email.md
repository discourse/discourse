# Email admission and identity

Use for incoming mail, DMARC claims, sender substitution or forwarded content.

## 1. Establish who controls the submission

- [ ] Identify SMTP delivery, mailbox polling or direct API ingestion.
- [ ] Separate control of message content from control of the trusted API caller.
  Trace how the deployed receiver authenticates its submission to Discourse.
- [ ] Record the actual receiver version, image, settings and route into Rails.

## 2. Verify upstream admission

- [ ] Identify where SPF, DKIM and DMARC are evaluated and where rejection or
  review is enforced. An enabled verifier does not establish rejection.
- [ ] Inspect the effective failure policy, including unknown results and verifier
  errors. For [mail-receiver](https://github.com/discourse/mail-receiver), inspect
  the deployed image's configuration and startup overrides. Verify what
  `RejectFailures` and `milter_default_action` actually enforce when applicable.
- [ ] Verify authentication result provenance: generating service, trusted
  `authserv-id`, handling of forged or duplicate headers, authenticated identity.
  A test supplying a matching header does not prove those properties.
- [ ] Exercise the real receiver when admission decides the claim. Record whether
  the message is rejected, deferred, delivered or queued for review.
- [ ] Trace Rails handling on the target revision. Verify how trusted DMARC
  failure, missing trusted configuration and unknown verdicts affect acceptance,
  rejection, review and immediate commands.

## 3. Follow identity after admission

- [ ] Compare the authenticated identity with the account selected for posting,
  forwarding, replies and immediate commands. DMARC domain alignment does not
  establish arbitrary mailbox ownership.
- [ ] Check whether parsing or sender substitution changes identity after validation.
- [ ] Follow the accepted input to the actual content, participant or account effect.
  Use [Identity and credentials](identity.md) or
  [Authorization and disclosure](authorization.md) if the path crosses those boundaries.

## Decision gate

- **Verified upstream rejection:** credit a trustworthy
  defense that actually blocks this input. An isolated downstream failure does
  not prove an exploitable Discourse vulnerability through that path.
- **Unknown enforcement or provenance:** keep exploitability `unconfirmed`.
  Do not invent a guarantee from a setting name or an injected `dmarc=pass`.
- **Input admitted:** continue through downstream defenses to observed damage.
- **Different ingress, genuine bypass, later identity transformation or independent
  impact:** assess that path separately. Do not dismiss email bugs as a class.
