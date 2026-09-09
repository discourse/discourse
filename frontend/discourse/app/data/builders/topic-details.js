// RPC-style endpoints; not CRUD, so they bypass `helpers.js`.

export function updateTopicNotificationLevel(topicId, level) {
  return {
    url: `/t/${encodeURIComponent(topicId)}/notifications`,
    method: "POST",
    options: { body: { notification_level: level } },
  };
}

export function removeAllowedTopicGroup(topicId, name) {
  return {
    url: `/t/${encodeURIComponent(topicId)}/remove-allowed-group`,
    method: "PUT",
    options: { body: { name } },
  };
}

export function removeAllowedTopicUser(topicId, username) {
  return {
    url: `/t/${encodeURIComponent(topicId)}/remove-allowed-user`,
    method: "PUT",
    options: { body: { username } },
  };
}
