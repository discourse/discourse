import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import MentionWithoutMembership from "discourse/plugins/chat/discourse/components/chat/notices/mention_without_membership";

const COMPONENT_DICT = {
  mention_without_membership: MentionWithoutMembership,
};

export default class ChatNotices extends Component {
  @service("chat-channel-notices-manager") noticesManager;

  @action
  clearNotice() {
    this.noticesManager.clearNotice(this.args.notice);
  }

  get component() {
    return COMPONENT_DICT[this.args.notice.type];
  }

  <template>
    <div class="chat-notices__notice">

      {{#if @notice.textContent}}
        <p class="chat-notices__notice__content">
          {{@notice.textContent}}
        </p>
      {{else}}
        <this.component
          @channel={{@channel}}
          @notice={{@notice}}
          @clearNotice={{this.clearNotice}}
        />
      {{/if}}

      <DButton
        @icon="xmark"
        @action={{this.clearNotice}}
        class="btn-transparent chat-notices__notice__clear"
      />
    </div>
  </template>
}
