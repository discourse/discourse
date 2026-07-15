import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ToggleChannelMembershipButton from "./toggle-channel-membership-button";

export default class ChatChannelPreviewCard extends Component {
  @service currentUser;

  get showJoinButton() {
    return this.args.channel?.isOpen && this.args.channel?.canJoin;
  }

  get channelPlaceholder() {
    return i18n("chat.placeholder_channel", {
      channelName: `#${this.args.channel.title}`,
    });
  }

  get guestTitle() {
    return i18n("chat.channel.preview_card.guest_title", {
      channelName: `#${this.args.channel.title}`,
    });
  }

  @action
  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  @action
  showCreateAccount() {
    getOwner(this).lookup("route:application").send("showCreateAccount");
  }

  <template>
    {{#if this.currentUser}}
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
    {{else}}
      <div class="chat-channel-preview-card --anon">
        <div class="chat-channel-preview-card__icon">
          {{dIcon "lock"}}
        </div>

        <div class="chat-channel-preview-card__content">
          <div class="chat-channel-preview-card__title">
            {{this.guestTitle}}
          </div>
          <div class="chat-channel-preview-card__body">
            {{i18n "chat.channel.preview_card.guest_body"}}
          </div>
        </div>

        <div class="chat-channel-preview-card__actions">
          <DButton
            @action={{this.showLogin}}
            @label="chat.channel.preview_card.log_in"
            class="btn-transparent --primary"
          />
          <DButton
            @action={{this.showCreateAccount}}
            @label="chat.channel.preview_card.sign_up"
            class="btn-primary"
          />
        </div>
      </div>
    {{/if}}
  </template>
}
