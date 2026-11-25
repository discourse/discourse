import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import { i18n } from "discourse-i18n";
import startChatConversation from "../lib/start-chat-conversation.js";

export default class WorkflowsChatLaunch extends Component {
  @tracked isStarting = false;

  @action
  async start() {
    this.isStarting = true;

    try {
      await startChatConversation({
        workflowId: this.args.workflowId,
        nodeId: this.args.nodeId,
      });
    } catch (error) {
      popupAjaxError(error);
      this.isStarting = false;
    }
  }

  <template>
    <div class="workflows-chat-launch">
      <DEmptyState
        @body={{i18n "discourse_workflows.chat_conversation.body"}}
        @ctaAction={{this.start}}
        @ctaDisabled={{this.isStarting}}
        @ctaLabel={{i18n "discourse_workflows.chat_conversation.start"}}
        @icon="comments"
        @identifier="workflows-chat-launch"
        @title={{i18n "discourse_workflows.chat_conversation.title"}}
      />
    </div>
  </template>
}
