import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import ChatChannelRow from "./chat-channel-row";

export default class ChannelsListPublic extends Component {
  @service chatChannelsManager;
  @service chatTrackingStateManager;
  @service site;
  @service siteSettings;
  @service currentUser;

  get inSidebar() {
    return this.args.inSidebar ?? false;
  }

  get publicMessageChannelsEmpty() {
    return this.chatChannelsManager.publicMessageChannels?.length === 0;
  }

  get displayPublicChannels() {
    if (!this.siteSettings.enable_public_channels) {
      return false;
    }

    if (this.publicMessageChannelsEmpty) {
      return (
        this.currentUser?.staff ||
        this.currentUser?.has_joinable_public_channels
      );
    }

    return true;
  }

  get hasUnreadThreads() {
    return this.chatTrackingStateManager.hasUnreadThreads;
  }

  get isThreadEnabledInAnyChannel() {
    return this.currentUser?.chat_channels?.public_channels?.some(
      (channel) => channel.threading_enabled
    );
  }

  @action
  toggleChannelSection(section) {
    this.args.toggleSection(section);
  }

  <template>
    {{#if (and this.site.desktopView this.isThreadEnabledInAnyChannel)}}
      <LinkTo @route="chat.threads" class="chat-channel-row --threads">
        <span class="chat-channel-title">
          {{dIcon "discourse-threads" class="chat-user-threads__icon"}}
          {{i18n "chat.my_threads.title"}}
        </span>
        {{#if this.hasUnreadThreads}}
          <div class="c-unread-indicator">
            <div class="c-unread-indicator__number">&nbsp;</div>
          </div>
        {{/if}}
      </LinkTo>
    {{/if}}

    {{#if this.displayPublicChannels}}
      {{#if this.site.desktopView}}
        <div class="chat-channel-divider public-channels-section">
          {{#if this.inSidebar}}
            <span
              class="title-caret"
              id="public-channels-caret"
              role="button"
              title="toggle nav list"
              {{on "click" (fn this.toggleChannelSection "public-channels")}}
              data-toggleable="public-channels"
            >
              {{dIcon "angle-up"}}
            </span>
          {{/if}}

          <span class="channel-title">{{i18n "chat.chat_channels"}}</span>

          <LinkTo
            @route="chat.browse"
            class="btn no-text btn-flat open-browse-page-btn title-action"
            title={{i18n "chat.channels_list_popup.browse"}}
          >
            {{dIcon "pencil-alt"}}
          </LinkTo>
        </div>
      {{/if}}

      <div
        id="public-channels"
        class={{concatClass
          "channels-list-container"
          "public-channels"
          (if this.inSidebar "collapsible-sidebar-section")
        }}
      >
        {{#if this.publicMessageChannelsEmpty}}
          <div class="channel-list-empty-message">
            <span class="channel-title">{{i18n
                "chat.no_public_channels"
              }}</span>
            <LinkTo @route="chat.browse">
              {{i18n "chat.click_to_join"}}
            </LinkTo>
          </div>
        {{else}}
          {{#each this.chatChannelsManager.publicMessageChannels as |channel|}}
            <ChatChannelRow
              @channel={{channel}}
              @options={{hash settingsButton=true}}
            />
          {{/each}}
        {{/if}}

      </div>
    {{/if}}

    <PluginOutlet
      @name="below-public-chat-channels"
      @tagName=""
      @outletArgs={{hash inSidebar=this.inSidebar}}
    />
  </template>
}
