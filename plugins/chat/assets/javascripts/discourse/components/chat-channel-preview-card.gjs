import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import ToggleChannelMembershipButton from "./toggle-channel-membership-button";

export default class ChatChannelPreviewCard extends Component {
  get showJoinButton() {
    return this.args.channel?.isOpen && this.args.channel?.canJoin;
  }

  get channelPlaceholder() {
    return i18n("chat.placeholder_channel", {
      channelName: `#${this.args.channel.title}`,
    });
  }

  <template>
    <div
      class={{dConcatClass
        "chat-channel-preview-card"
        (unless this.showJoinButton "-no-button")
      }}
    >
      {{#if this.showJoinButton}}
        <div class="chat-channel__placeholder">
          {{this.channelPlaceholder}}
        </div>

        <ToggleChannelMembershipButton
          @channel={{@channel}}
          @options={{hash joinClass="btn-primary" labelType="short"}}
        />
      {{/if}}
    </div>
  </template>
}
