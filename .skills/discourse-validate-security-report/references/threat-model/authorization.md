# Authorization and disclosure

Use for PMs, groups, moderation, private data, API restrictions or MCP scopes.

## 1. Check the exact operation

- [ ] Identify the actor's actual scope: trust level, category moderator, group
  owner, moderator, administrator or delegated API identity.
- [ ] Check the specific Guardian decision and setting. Visibility, posting,
  moderation, ownership and private flag access grant different operations.
  Moderators do not inherit every administrator permission.
- [ ] For moves, check source and destination rights, including ownership changes.
  **Observed defenses:** [Source and destination move rights](https://github.com/discourse/discourse/commit/4eca9332051a99b1ff516f9d6bf6fdb24ab9c655) and
  [chronological topic ownership changes](https://github.com/discourse/discourse/commit/a8f33a29ac86b157933fb2479e7dfa8511820af9) require more than read or reply access.

## 2. Check the disclosure audience

- [ ] Follow error and conflict bodies, review queues, histories, diffs, deleted
  records, RSS, crawler metadata, exports, email and notifications as well as JSON.
- [ ] Check each whisper, hidden post, revision, group member and field. Topic
  access alone does not grant access to all of them.
- [ ] Recheck access when deferred work runs. Old ownership, subscriptions, invites
  and cached audiences may survive permission changes.
- [ ] Inspect retained MessageBus data. **Observed defense:** [Polls](https://github.com/discourse/discourse/commit/9a600a9cc6346e781f991ccb2e0aa7b1cc220e12) publish
  invalidations and fetch content with current permissions.
- [ ] **Group history:** select the complete allowed field set
  for the viewer's scope, with an administrator bypass. The [landed allow lists](https://github.com/discourse/discourse/commit/cfa7b412b21ecb599500f1160eaf3bc0556e2358)
  redact unknown subjects. Do not impose that exact implementation on every serializer.

## 3. Check delegated capabilities

- [ ] Compare API scope restrictions with the selector actually used by the
  controller, including aliases and extra path, query or body selectors.
  **Observed defense:** [API selectors](https://github.com/discourse/discourse/commit/8f07b086b6e27963c5e3e0ca9d690b5ab5246254) reject selectors outside restricted paths.
- [ ] Require both MCP token scope and the user's content permission, including
  PM scopes for deleted drafts and plugin metadata. See [MCP scope checks](https://github.com/discourse/discourse/commit/12f263e580aeb45bf2881347c8fe34179c3e6e8b).
- [ ] Check whether an agent supplies approval that requires a person.
  **Observed defense:** an AI tool cannot provide the
  [human approval its own action requires](https://github.com/discourse/discourse/commit/607d5971431aff47af8edb81b63bfb02c2ab9210) even when acting for staff.

## Decision gate

- **Denied:** inspect the returned body and side effects before treating the
  request as harmless. A 403 can still disclose data or follow a partial mutation.
- **Allowed:** compare the observed fields or state changes with the actor's
  actual permission. Name the boundary crossed and the affected owner.
- **Only a stale audience is suspected:** reproduce permission loss and subsequent
  delivery. Do not substitute the historical membership record for current access.
