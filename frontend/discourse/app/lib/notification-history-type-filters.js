const TYPE_FILTERS = [
  ["mentions", ["mentioned", "group_mentioned"]],
  ["replies", ["replied"]],
  ["quotes", ["quoted"]],
  ["edits", ["edited", "suggested_edit_created", "suggested_edit_accepted"]],
  ["likes", ["liked", "liked_consolidated", "reaction", "boost"]],
  [
    "messages",
    ["private_message", "invited_to_private_message", "group_message_summary"],
  ],
  ["badges", ["granted_badge"]],
  ["links", ["linked", "linked_consolidated"]],
  ["reminders", ["topic_reminder", "bookmark_reminder", "event_reminder"]],
  ["watching", ["posted", "watching_first_post", "watching_category_or_tag"]],
];

const GROUPED_TYPES = new Set(TYPE_FILTERS.flatMap(([, types]) => types));

export default function notificationHistoryTypeFilters(notificationTypes) {
  const available = new Set(Object.keys(notificationTypes ?? {}));
  const filters = TYPE_FILTERS.map(([key, types]) => [
    key,
    types.filter((type) => available.has(type)),
  ]);

  filters.push([
    "other",
    [...available].filter((type) => !GROUPED_TYPES.has(type)),
  ]);

  return new Map(filters.filter(([, types]) => types.length));
}
