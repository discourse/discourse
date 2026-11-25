import { service } from "@ember/service";
import cookie from "discourse/lib/cookie";
import DiscourseRoute from "discourse/routes/discourse";
import startChatConversation from "../lib/start-chat-conversation.js";

export default class WorkflowsChatRoute extends DiscourseRoute {
  @service currentUser;
  @service router;

  async beforeModel() {
    if (!this.currentUser) {
      cookie("destination_url", window.location.href);
      return this.router.replaceWith("login");
    }

    const {
      workflow_id: workflowId,
      node_id: nodeId,
      draft,
    } = this.paramsFor(this.routeName);

    // Any link, history entry or restored URL can lead here, so starting a conversation
    // takes a click. Only a draft starts at once: the server refuses it to everyone but
    // workflow managers.
    if (draft) {
      await startChatConversation({ workflowId, nodeId, draft });
    }
  }

  model({ workflow_id: workflowId, node_id: nodeId }) {
    return { workflowId, nodeId };
  }
}
