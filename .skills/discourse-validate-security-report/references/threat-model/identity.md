# Identity and credentials

Use for signup, login, invites, external authentication, OTPs, 2FA or revocation.

## 1. Establish the identity and intended contract

- [ ] Separate submitted email, verified mailbox, provider identity, staged account
  and persisted account. Record the actual value and owner at each step.
- [ ] Trace confirmation, email changes and activation before PM or group grants.
  **Observed defense:** [Email code activation](https://github.com/discourse/discourse/commit/456a57c98d682b19fa4cd87f87da4d7c2b87b9d7) binds the effect to the
  address actually verified.
- [ ] For external username overrides, compare the old username supplied to jobs
  with persisted ownership. Final username uniqueness alone cannot establish this.
  **Observed defense:** the [external signup fix](https://github.com/discourse/discourse/commit/0382381cf17740346b7a4c16daeb772d98db2437) uses stored identity for
  existing users and assigns new users without invoking a rename.
- [ ] Check whether a fetch changes session state. **Observed defense:**
  [DiscourseConnect invite continuation](https://github.com/discourse/discourse/commit/74c7b46a973d02abbe23c6812a2fed7e1ae073e7) uses a CSRF protected POST so merely
  fetching an invite URL cannot attach it to the browser session.

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
- [ ] Where revocation is promised, test each channel that retains access.
  **Observed defenses:** [Global revocation clears web push subscriptions](https://github.com/discourse/discourse/commit/9da8c122c6663171a8d7feb2de51acc197199107).
  [Calendar revocation](https://github.com/discourse/discourse/commit/c639b37e6f1aedb136b763500881830a14e26441) finds keys by scope despite mutable client association.
- [ ] For TOTP replay, check the accepted time step and drift window.
  **Observed defense:** replay protection records the [matched time step](https://github.com/discourse/discourse/commit/ae954380e0162aa4e9b7f852ab7d20947d85d499).
- [ ] Check grants and cleanup ordering on the target release. A successful cherry
  pick does not establish equivalent behavior or preserve pending invitations.

## Decision gate

- **Already authorized by the contract:** identify any additional boundary crossed
  before claiming escalation. Intended handoff is not itself account takeover.
- **Contract or ownership unknown:** record the missing evidence before judging
  continued access a vulnerability.
- **Contract exceeded:** demonstrate the resulting session, grant or unauthorized
  operation. Score that consequence, not possession of a token alone.
