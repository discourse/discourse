# Identity and credentials

Use for signup, login, invites, external authentication, OTPs, 2FA or revocation.

## 1. Establish identity and contract

- [ ] Track submitted email, verified mailbox, provider identity, staged account
  and persisted account, including each value and owner.
- [ ] Trace confirmation, email changes and activation before PM or group grants.
  Activation must use the verified address even if primary email changes before redemption.
- [ ] Compare external username override jobs with persisted ownership. Uniqueness
  alone is insufficient. Check whether initial assignment triggers another
  account's rename work and whether existing accounts use persisted identity.
- [ ] For DiscourseConnect invites, check whether fetching the URL attaches it to
  the session. Verify intent and CSRF protection when redemption starts.

## 2. Establish credential purpose

- [ ] Establish the contract before calling continued use a bypass. A login
  handoff ticket is not a second factor.
- [ ] Distinguish intended possession from gaining or retaining excess access.
  Do not assume parent revocation revokes every derived capability.
- [ ] Identify issuing credential, scope, expiry and promised revocation. Use
  [Authorization](authorization.md) for scope or selector checks.

## 3. Exercise the lifecycle

- [ ] Show issuance → revocation or expiry → reuse attempt → resulting access.
- [ ] Distinguish unused tickets from sessions created by redemption.
- [ ] Test promised revocation across retained access channels, including push
  subscriptions and calendar URLs. Check mutable client metadata in credential
  lookup and revocation.
- [ ] For TOTP, check accepted step and drift window. Retry a code accepted ahead
  of server time after its step becomes current.
- [ ] Verify grant and cleanup ordering on the target release. Applying a change
  cleanly does not prove equivalent behavior or preserved pending invitations.

## Decision gate

- **Already authorized:** identify an additional boundary before claiming escalation.
  Intended handoff is not account takeover.
- **Unknown contract or ownership:** record missing evidence before judging
  continued access a vulnerability.
- **Contract exceeded:** demonstrate the session, grant or unauthorized operation.
  Score that consequence, not token possession alone.
