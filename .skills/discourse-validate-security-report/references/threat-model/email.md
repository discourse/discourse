# Email admission and identity

Use for incoming mail, DMARC claims, sender substitution or forwarded content.

## 1. Establish who controls the submission

- [ ] Identify SMTP delivery, mailbox polling or direct API ingestion.
- [ ] Separate control of message content from control of the trusted API caller.
  The [receiver container](https://github.com/discourse/discourse_docker/blob/0ba1841d589e77df3bc923774abca2720a320ec2/samples/mail-receiver.yml) posts mail using an API credential.
- [ ] Record the actual receiver version, image, settings and route into Rails.

## 2. Verify upstream admission

- [ ] Identify where SPF, DKIM and DMARC are evaluated and where rejection or
  review is enforced. An enabled verifier does not establish rejection.
- [ ] Inspect the effective failure policy, including unknown results and verifier
  errors. **Observed defense:** the public [mail receiver configuration](https://github.com/discourse/mail-receiver/blob/b2001d262b84b5f59a41d22f28e21e0a4abbcc08/opendmarc.conf)
  leaves `RejectFailures` disabled and its [Dockerfile](https://github.com/discourse/mail-receiver/blob/b2001d262b84b5f59a41d22f28e21e0a4abbcc08/Dockerfile) uses
  `milter_default_action=accept`.
- [ ] Verify authentication result provenance: generating service, trusted
  `authserv-id`, handling of forged or duplicate headers, authenticated identity.
  A test supplying a matching header does not prove those properties.
- [ ] Exercise the real receiver when admission decides the claim. Record whether
  the message is rejected, deferred, delivered or queued for review.
- [ ] Check Rails handling too. **Observed defense:** [`AuthenticationResults`](https://github.com/discourse/discourse/blob/8a4eb63d20745c1038ce4a13d97d48065eb54099/lib/email/authentication_results.rb)
  queues explicit trusted DMARC failure. Missing trusted configuration or an
  unknown verdict does not itself require review.

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
