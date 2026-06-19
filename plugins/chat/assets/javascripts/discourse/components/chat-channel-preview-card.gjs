import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import ToggleChannelMembershipButton from "./toggle-channel-membership-button";

export default class ChatChannelPreviewCard extends Component {
  get showJoinButton() {
    return this.args.channel?.isOpen && this.args.channel?.canJoin;
  }

  <template>
    <div
      class={{dConcatClass
        "chat-channel-preview-card"
        (unless this.showJoinButton "-no-button")
      }}
    >
      {{#if this.showJoinButton}}
        <ToggleChannelMembershipButton
          @channel={{@channel}}
          @options={{hash joinClass="btn-primary"}}
        />
      {{/if}}
    </div>
  </template>
}
