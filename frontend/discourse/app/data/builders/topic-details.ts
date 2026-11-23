import type { RpcRequest } from "discourse/data/builders/helpers";
import type { WarpResourceId } from "discourse/data/warp-rest-model";

// RPC-style endpoints; not CRUD, so they bypass `helpers.ts`.

export function updateTopicNotificationLevel(
  topicId: WarpResourceId,
  level: number
): RpcRequest {
  return {
    url: `/t/${encodeURIComponent(topicId)}/notifications`,
    method: "POST",
    options: { body: { notification_level: level } },
  };
}

export function removeAllowedTopicGroup(
  topicId: WarpResourceId,
  name: string
): RpcRequest {
  return {
    url: `/t/${encodeURIComponent(topicId)}/remove-allowed-group`,
    method: "PUT",
    options: { body: { name } },
  };
}

export function removeAllowedTopicUser(
  topicId: WarpResourceId,
  username: string
): RpcRequest {
  return {
    url: `/t/${encodeURIComponent(topicId)}/remove-allowed-user`,
    method: "PUT",
    options: { body: { username } },
  };
}
