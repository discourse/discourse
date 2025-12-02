import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

export default class ChatNavbarChannelTitle extends Component {
  @service chatApi;
  @service chatStateManager;
  @service siteSettings;

  @tracked isTogglingStarred = false;

  get shouldLinkToSettings() {
    return (
      this.chatStateManager.isDrawerExpanded ||
      this.chatStateManager.isFullPageActive
    );
  }

  get isStarred() {
    return this.args.channel?.currentUserMembership?.starred;
  }

  get starIcon() {
    return this.isStarred ? "star" : "far-star";
  }

  get starTooltip() {
    return this.isStarred
      ? i18n("chat.channel_settings.unstar_channel")
      : i18n("chat.channel_settings.star_channel");
  }

  get showStarButton() {
    return (
      this.args.channel?.currentUserMembership &&
      this.siteSettings.star_chat_channels
    );
  }

  @action
  async toggleStarred() {
    const channel = this.args.channel;
    if (!channel?.currentUserMembership || this.isTogglingStarred) {
      return;
    }

    const newValue = !channel.currentUserMembership.starred;
    const previousValue = channel.currentUserMembership.starred;

    channel.currentUserMembership.starred = newValue;
    this.isTogglingStarred = true;

    try {
      await this.chatApi.updateCurrentUserChannelMembership(channel.id, {
        starred: newValue,
      });
    } catch {
      channel.currentUserMembership.starred = previousValue;
    } finally {
      this.isTogglingStarred = false;
    }
  }

  <template>
    {{#if @channel}}
      {{#if this.shouldLinkToSettings}}
        <LinkTo
          @route="chat.channel.info.settings"
          @models={{@channel.routeModels}}
          class="c-navbar__channel-title"
        >
          <ChannelTitle @channel={{@channel}} />
        </LinkTo>
      {{else}}
        <div class="c-navbar__channel-title">
          <ChannelTitle @channel={{@channel}} />
        </div>
      {{/if}}
      {{#if this.showStarButton}}
        <DTooltip @placement="bottom">
          <:trigger>
            <DButton
              @action={{this.toggleStarred}}
              @icon={{this.starIcon}}
              @disabled={{this.isTogglingStarred}}
              class={{concatClass
                "btn-transparent"
                "c-navbar__star-channel-button"
                (if this.isStarred "--starred")
              }}
            />
          </:trigger>
          <:content>
            {{this.starTooltip}}
          </:content>
        </DTooltip>
      {{/if}}
    {{/if}}
  </template>
}
