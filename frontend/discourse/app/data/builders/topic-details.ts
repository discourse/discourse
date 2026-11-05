import type { WarpRequest } from "discourse/data/warp-rest-model";

// RPC-style endpoints; not CRUD, so they bypass `helpers.ts`.

export function updateTopicNotificationLevel(
  topicId: string | number,
  level: number
): WarpRequest {
  return {
    url: `/t/${encodeURIComponent(topicId)}/notifications`,
    method: "POST",
    options: { body: { notification_level: level } },
  };
}

export function removeAllowedTopicGroup(
  topicId: string | number,
  name: string
): WarpRequest {
  return {
    url: `/t/${encodeURIComponent(topicId)}/remove-allowed-group`,
    method: "PUT",
    options: { body: { name } },
  };
}

export function removeAllowedTopicUser(
  topicId: string | number,
  username: string
): WarpRequest {
  return {
    url: `/t/${encodeURIComponent(topicId)}/remove-allowed-user`,
    method: "PUT",
    options: { body: { username } },
  };
}
