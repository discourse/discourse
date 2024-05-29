import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import ChannelTitle from "./channel-title";
import ToggleChannelMembershipButton from "./toggle-channel-membership-button";

export default class ChatChannelPreviewCard extends Component {
  @service chat;

  get showJoinButton() {
    return this.args.channel?.isOpen && this.args.channel?.canJoin;
  }

  get hasDescription() {
    return !isEmpty(this.args.channel?.description);
  }

  <template>
    <div
      class={{concatClass
        "chat-channel-preview-card"
        (unless this.hasDescription "-no-description")
        (unless this.showJoinButton "-no-button")
      }}
    >
      <ChannelTitle @channel={{@channel}} />
      {{#if this.hasDescription}}
        <p class="chat-channel-preview-card__description">
          {{@channel.description}}
        </p>
      {{/if}}
      {{#if this.showJoinButton}}
        <ToggleChannelMembershipButton
          @channel={{@channel}}
          @options={{hash joinClass="btn-primary"}}
        />
      {{/if}}
      <LinkTo
        @route="chat.browse"
        class="chat-channel-preview-card__browse-all"
      >
        {{i18n "chat.browse_all_channels"}}
      </LinkTo>
    </div>
  </template>
}
