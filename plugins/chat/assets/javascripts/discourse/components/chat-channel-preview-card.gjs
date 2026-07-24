import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ToggleChannelMembershipButton from "./toggle-channel-membership-button";

export default class ChatChannelPreviewCard extends Component {
  @service currentUser;

  get showJoinButton() {
    return this.args.channel?.isOpen && this.args.channel?.canJoin;
  }

  get guestTitle() {
    return i18n("chat.channel.preview_card.guest_title", {
      channelName: `#${this.args.channel.title}`,
    });
  }

  get noAccessTitle() {
    return i18n("chat.channel.preview_card.no_access_title", {
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
      {{#if this.showJoinButton}}
        <div class="chat-channel-preview-card --logged-in">
          <PluginOutlet
            @name="chat-channel-preview-card-content"
            @outletArgs={{lazyHash channel=@channel context=@context}}
            @defaultGlimmer={{true}}
          >
            <div class="chat-channel-preview-card__icon">
              {{dIcon "lock"}}
            </div>

            <div class="chat-channel-preview-card__title">
              {{this.guestTitle}}
            </div>

            <div class="chat-channel-preview-card__body">
              {{i18n "chat.channel.preview_card.join_body"}}
            </div>

            <div class="chat-channel-preview-card__actions">
              <ToggleChannelMembershipButton
                @channel={{@channel}}
                @options={{hash joinClass="btn-primary" labelType="short"}}
              />
            </div>
          </PluginOutlet>
        </div>
      {{else}}
        <div class="chat-channel-preview-card --logged-in --no-access">
          <div class="chat-channel-preview-card__icon">
            {{dIcon "lock"}}
          </div>

          <div class="chat-channel-preview-card__title">
            {{this.noAccessTitle}}
          </div>

          <div class="chat-channel-preview-card__body">
            {{i18n "chat.channel.preview_card.no_access_body"}}
          </div>
        </div>
      {{/if}}
    {{else}}
      <div class="chat-channel-preview-card --anon">
        <div class="chat-channel-preview-card__icon">
          {{dIcon "lock"}}
        </div>

        <div class="chat-channel-preview-card__title">
          {{this.guestTitle}}
        </div>

        <div class="chat-channel-preview-card__body">
          {{i18n "chat.channel.preview_card.guest_body"}}
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
