import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";

/**
 * Opens a new chat with the workflow's chat trigger and takes the member to it.
 *
 * @param {Object} target
 * @param {number|string} target.workflowId
 * @param {string} target.nodeId - The chat trigger node in that workflow.
 * @param {boolean} [target.draft] - Runs the unpublished draft instead of the published workflow.
 */
export default async function startChatConversation({
  workflowId,
  nodeId,
  draft = false,
}) {
  const { url } = await ajax("/workflows/chat-conversations.json", {
    type: "POST",
    data: { workflow_id: workflowId, node_id: nodeId, draft },
  });

  DiscourseURL.routeTo(url, { replaceURL: true });
}
