# Authorization and disclosure

Use for PMs, groups, moderation, private data, API restrictions or MCP scopes.

## 1. Check the operation

- [ ] Identify actual scope: trust level, category moderator, group owner,
  moderator, administrator or delegated API identity.
- [ ] Check the exact Guardian decision and setting. Visibility, posting,
  moderation, ownership and private flags are distinct permissions.
  Moderators do not inherit every administrator permission.
- [ ] For moves, check source, destination and resulting ownership permissions.
  Earlier inserted posts may replace the first post or topic owner. Read or
  reply access alone does not authorize that effect.

## 2. Check the audience

- [ ] Inspect errors, conflicts, reviews, histories, diffs, deleted records, RSS,
  crawler metadata, exports, email and notifications, not just JSON.
- [ ] Check each whisper, hidden post, revision, member and field independently
  of topic access.
- [ ] Recheck deferred work after permission changes. Old ownership, subscriptions,
  invites and cached audiences can persist.
- [ ] Inspect retained MessageBus and poll updates: content or invalidation?
  Reproduce delivery and followup fetch after access loss.
- [ ] For group history, compare every field with allowed fields and intended
  administrator bypass. Test unknown subjects and the target serializer's own policy.

## 3. Check delegated capabilities

- [ ] Compare API scope with actual controller selectors, including aliases and
  extra path, query or body selectors. Can an allowed path select another record?
- [ ] Require and exercise both MCP token scope and user content permission at the tool
  endpoint, including PM scopes for deleted drafts and plugin metadata.
- [ ] Can an AI tool supply the human approval its action requires, even when
  acting with staff permissions?

## Decision gate

- **Denied:** inspect response and side effects. A 403 can disclose data or follow
  partial mutation.
- **Allowed:** compare fields and changes with actual permission. Name the boundary
  and affected owner.
- **Suspected stale audience:** reproduce access loss and later delivery.
  Historical membership does not establish current access.
