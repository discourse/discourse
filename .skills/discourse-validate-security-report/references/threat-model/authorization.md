# Authorization and disclosure

Use for PMs, groups, moderation, private data, API restrictions or MCP scopes.

## 1. Check the exact operation

- [ ] Identify the actor's actual scope: trust level, category moderator, group
  owner, moderator, administrator or delegated API identity.
- [ ] Check the specific Guardian decision and setting. Visibility, posting,
  moderation, ownership and private flag access grant different operations.
  Moderators do not inherit every administrator permission.
- [ ] For moves, check source and destination rights. Determine whether inserting
  earlier posts can replace the first post or change topic ownership, then verify
  permission for that effect rather than relying on read or reply access.

## 2. Check the disclosure audience

- [ ] Follow error and conflict bodies, review queues, histories, diffs, deleted
  records, RSS, crawler metadata, exports, email and notifications as well as JSON.
- [ ] Check each whisper, hidden post, revision, group member and field. Topic
  access alone does not grant access to all of them.
- [ ] Recheck access when deferred work runs. Old ownership, subscriptions, invites
  and cached audiences may survive permission changes.
- [ ] Inspect retained MessageBus data, including poll updates. Determine whether
  messages contain content or only invalidations. Reproduce delivery and any
  followup fetch after the reader loses access.
- [ ] **Group history:** compare returned values with the viewer's complete allowed
  field set and intended administrator bypass. Check unknown subjects too.
  Verify the target serializer's policy rather than assuming every serializer
  uses the same implementation.

## 3. Check delegated capabilities

- [ ] Compare API scope restrictions with the selector actually used by the
  controller, including aliases and extra path, query or body selectors.
  Test whether an allowed path can authorize a different record selected elsewhere.
- [ ] Require both MCP token scope and the user's content permission, including
  PM scopes for deleted drafts and plugin metadata. Exercise both checks through
  the target tool endpoint.
- [ ] Check whether an AI tool can supply the human approval its own action
  requires, including when it acts with a staff user's permissions.

## Decision gate

- **Denied:** inspect the returned body and side effects before treating the
  request as harmless. A 403 can still disclose data or follow a partial mutation.
- **Allowed:** compare the observed fields or state changes with the actor's
  actual permission. Name the boundary crossed and the affected owner.
- **Only a stale audience is suspected:** reproduce permission loss and subsequent
  delivery. Do not substitute the historical membership record for current access.
