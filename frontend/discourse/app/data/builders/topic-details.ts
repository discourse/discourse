import type { RpcRequest } from "discourse/data/builders/helpers";

// RPC-style endpoints; not CRUD, so they bypass `helpers.ts`.

export function updateTopicNotificationLevel(
  topicId: string | number,
  level: number
): RpcRequest {
  return {
    url: `/t/${encodeURIComponent(topicId)}/notifications`,
    method: "POST",
    options: { body: { notification_level: level } },
  };
}

export function removeAllowedTopicGroup(
  topicId: string | number,
  name: string
): RpcRequest {
  return {
    url: `/t/${encodeURIComponent(topicId)}/remove-allowed-group`,
    method: "PUT",
    options: { body: { name } },
  };
}

export function removeAllowedTopicUser(
  topicId: string | number,
  username: string
): RpcRequest {
  return {
    url: `/t/${encodeURIComponent(topicId)}/remove-allowed-user`,
    method: "PUT",
    options: { body: { username } },
  };
}
