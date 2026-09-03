import {
  indexIncluded,
  maybeRelate,
  resourceFrom,
} from "discourse/data/jsonapi-utils";
import { BadgeSchema } from "discourse/data/schemas/badge";
import { BadgeGroupingSchema } from "discourse/data/schemas/badge-grouping";
import { BadgeTypeSchema } from "discourse/data/schemas/badge-type";
import { TopicDetailsSchema } from "discourse/data/schemas/topic-details";
import { UserBadgeSchema } from "discourse/data/schemas/user-badge";
import { badgeGroupingDisplayName } from "discourse/models/badge-grouping";

function badgeResource(raw, includedIds) {
  const resource = resourceFrom("badge", BadgeSchema, raw);
  const relationships = {};
  maybeRelate(
    relationships,
    "badge_type",
    includedIds,
    "badge-type",
    raw.badge_type_id
  );
  maybeRelate(
    relationships,
    "badge_grouping",
    includedIds,
    "badge-grouping",
    raw.badge_grouping_id
  );
  resource.relationships = relationships;
  return resource;
}

function badgeTypeResource(raw) {
  return resourceFrom("badge-type", BadgeTypeSchema, raw);
}

function badgeGroupingResource(raw) {
  const resource = resourceFrom("badge-grouping", BadgeGroupingSchema, raw);
  if (raw.name) {
    resource.attributes.displayName = badgeGroupingDisplayName(raw.name);
  }
  return resource;
}

function userBadgeResource(raw, lookup, includedIds) {
  const resource = resourceFrom("user-badge", UserBadgeSchema, raw);
  const { attributes } = resource;
  // Inline sideloads as plain objects so templates can read arbitrary fields
  // without hitting LegacyMode's strict schema check on cached records.
  if (raw.user_id != null) {
    attributes.user = lookup.user(raw.user_id);
  }
  if (raw.granted_by_id != null) {
    attributes.granted_by = lookup.user(raw.granted_by_id);
  }
  if (raw.topic_id != null) {
    attributes.topic = lookup.topic(raw.topic_id);
  }

  const relationships = {};
  maybeRelate(relationships, "badge", includedIds, "badge", raw.badge_id);
  resource.relationships = relationships;
  return resource;
}

function collectBadgeMetaIncluded(payload, included) {
  for (const raw of payload.badge_types ?? []) {
    included.push(badgeTypeResource(raw));
  }
  for (const raw of payload.badge_groupings ?? []) {
    included.push(badgeGroupingResource(raw));
  }
}

// Accepts:
//   { badge: {...},  badge_types: [...], badge_groupings?: [...] }   (show)
//   { badges: [...], badge_types: [...], badge_groupings: [...] }    (index)
// A payload carrying neither is an empty collection, not an absent record:
// badges ride along in larger payloads (a user summary, a post) that may
// simply have none, and callers there expect a list. Only a missing payload
// is `{ data: null }` (no `included` — JSON:API forbids it when data is null).
export function normalizeBadgesPayload(payload) {
  if (!payload) {
    return { data: null };
  }
  const included = [];
  collectBadgeMetaIncluded(payload, included);
  const includedIds = indexIncluded(included);

  if (payload.badge) {
    return { data: badgeResource(payload.badge, includedIds), included };
  }
  return {
    data: (payload.badges ?? []).map((raw) => badgeResource(raw, includedIds)),
    included,
  };
}

// Accepts:
//   { user_badge: {...}, badges, badge_types, users, topics, granted_bies }      (grant POST)
//   { user_badges: [...], badges, badge_types, users, topics, granted_bies }     (findByUsername)
//   { user_badge_info: { user_badges, grant_count, username }, badges, ... }     (findByBadgeId)
export function normalizeUserBadgesPayload(payload) {
  if (!payload) {
    return { data: null };
  }
  const included = [];
  collectBadgeMetaIncluded(payload, included);
  // Index BEFORE pushing sideloaded badges so each badge's relationships only
  // reference badge-type / badge-grouping resources we actually included.
  const badgeRelIds = indexIncluded(included);
  for (const raw of payload.badges ?? []) {
    included.push(badgeResource(raw, badgeRelIds));
  }
  const includedIds = indexIncluded(included);

  const usersById = new Map();
  for (const raw of [
    ...(payload.users ?? []),
    ...(payload.granted_bies ?? []),
  ]) {
    if (!usersById.has(raw.id)) {
      usersById.set(raw.id, raw);
    }
  }
  const topicsById = new Map();
  for (const raw of payload.topics ?? []) {
    topicsById.set(raw.id, raw);
  }
  const lookup = {
    user: (id) => usersById.get(id),
    topic: (id) => topicsById.get(id),
  };

  if (payload.user_badge) {
    return {
      data: userBadgeResource(payload.user_badge, lookup, includedIds),
      included,
    };
  }

  const wrapper = payload.user_badge_info;
  const rawUserBadges = wrapper?.user_badges ?? payload.user_badges ?? [];
  const doc = {
    data: rawUserBadges.map((ub) => userBadgeResource(ub, lookup, includedIds)),
    included,
  };
  if (wrapper) {
    doc.meta = {
      grant_count: wrapper.grant_count,
      username: wrapper.username,
    };
  }
  return doc;
}

// Single-record ops (findRecord / createRecord / updateRecord) must resolve to
// exactly one resource, so a payload without the record key is a no-op rather
// than an empty collection — `{ data: [] }` fails the cache validator.
function recordOnly(normalize, rootKey) {
  return (payload) =>
    payload?.[rootKey] ? normalize(payload) : { data: null };
}

export const normalizeBadgeRecordPayload = recordOnly(
  normalizeBadgesPayload,
  "badge"
);

export const normalizeUserBadgeRecordPayload = recordOnly(
  normalizeUserBadgesPayload,
  "user_badge"
);

export function normalizeTopicDetailsPayload({ topicId, details }) {
  return {
    data: resourceFrom("topic-details", TopicDetailsSchema, details, topicId),
  };
}
