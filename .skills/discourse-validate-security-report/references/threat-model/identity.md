# Identity and credentials

Use for signup, login, invites, external authentication, OTPs, 2FA or revocation.

## 1. Establish the identity and intended contract

- [ ] Separate submitted email, verified mailbox, provider identity, staged account
  and persisted account. Record the actual value and owner at each step.
- [ ] Trace confirmation, email changes and activation before PM or group grants.
  Verify that activation uses the address actually verified, including when the
  primary email changes before code redemption.
- [ ] For external username overrides, compare the old username supplied to jobs
  with persisted ownership. Final username uniqueness alone cannot establish this.
  Check whether a new account's initial assignment can trigger rename work for
  another account, and whether existing accounts use their persisted identity.
- [ ] For DiscourseConnect invites, test whether merely fetching an invite URL
  can attach it to the browser session. Verify user intent and CSRF protection
  for the action that starts redemption.

## 2. Test the credential's actual purpose

- [ ] Establish the intended purpose before calling continued
  use a bypass. A login handoff ticket is not a second factor.
- [ ] Distinguish authorized possession from gaining or retaining access beyond
  the contract. Do not assume parent revocation revokes every derived capability.
- [ ] Identify the issuing credential, delegated scope, expiry and promised
  revocation behavior. Use [Authorization and disclosure](authorization.md)
  for scope or selector restrictions.

## 3. Exercise the lifecycle

- [ ] Show issuance → revocation or expiry → attempted reuse → resulting access.
- [ ] Separate unused tickets from sessions already created by redemption.
- [ ] Where revocation is promised, test each channel that retains access,
  including web push subscriptions and calendar feed URLs. Check whether mutable
  client metadata can cause credential lookup or revocation to miss a key.
- [ ] For TOTP replay, check the accepted time step and drift window. Test reuse
  after a code accepted ahead of server time becomes the current step.
- [ ] Check grants and cleanup ordering on the target release. A successful cherry
  pick does not establish equivalent behavior or preserve pending invitations.

## Decision gate

- **Already authorized by the contract:** identify any additional boundary crossed
  before claiming escalation. Intended handoff is not itself account takeover.
- **Contract or ownership unknown:** record the missing evidence before judging
  continued access a vulnerability.
- **Contract exceeded:** demonstrate the resulting session, grant or unauthorized
  operation. Score that consequence, not possession of a token alone.
