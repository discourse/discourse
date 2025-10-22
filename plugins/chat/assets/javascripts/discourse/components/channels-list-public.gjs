import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import EmptyState from "discourse/components/empty-state";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import ChatChannelRow from "./chat-channel-row";
import ChatZero from "./svg/chat-zero";

export default class ChannelsListPublic extends Component {
  @service chatChannelsManager;
  @service chatTrackingStateManager;
  @service site;
  @service router;

  get inSidebar() {
    return this.args.inSidebar ?? false;
  }

  get hasUnreadThreads() {
    return this.chatTrackingStateManager.hasUnreadThreads;
  }

  get hasThreadedChannels() {
    return this.chatChannelsManager.hasThreadedChannels;
  }

  get channelList() {
    return this.chatChannelsManager.publicMessageChannelsByActivity;
  }

  @action
  toggleChannelSection(section) {
    this.args.toggleSection(section);
  }

  @action
  openBrowseChannels() {
    this.router.transitionTo("chat.browse");
  }

  <template>
    {{#if (and this.site.desktopView this.inSidebar this.hasThreadedChannels)}}
      <LinkTo @route="chat.threads" class="chat-channel-row --threads">
        <span class="chat-channel-title">
          {{icon "discourse-threads" class="chat-user-threads__icon"}}
          {{i18n "chat.my_threads.title"}}
        </span>
        {{#if this.hasUnreadThreads}}
          <div class="c-unread-indicator">
            <div class="c-unread-indicator__number">&nbsp;</div>
          </div>
        {{/if}}
      </LinkTo>
    {{/if}}

    {{#if
      (and this.chatChannelsManager.displayPublicChannels this.site.desktopView)
    }}
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
            {{icon "angle-up"}}
          </span>
        {{/if}}

        <span class="channel-title">{{i18n "chat.chat_channels"}}</span>

        <LinkTo
          @route="chat.browse"
          class="btn no-text btn-flat open-browse-page-btn title-action"
          title={{i18n "chat.channels_list_popup.browse"}}
        >
          {{icon "pencil"}}
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
      {{#if this.chatChannelsManager.publicMessageChannelsEmpty}}
        <EmptyState
          @identifier="empty-channels-list"
          @svgContent={{ChatZero}}
          @title={{i18n "chat.no_public_channels"}}
          @ctaLabel={{if
            this.chatChannelsManager.displayPublicChannels
            (i18n "chat.no_public_channels_cta")
          }}
          @ctaAction={{this.openBrowseChannels}}
        />
      {{else}}
        {{#each this.channelList as |channel|}}
          <ChatChannelRow
            @channel={{channel}}
            @options={{hash settingsButton=true}}
          />
        {{/each}}
      {{/if}}
    </div>

    <PluginOutlet
      @name="below-public-chat-channels"
      @tagName=""
      @outletArgs={{lazyHash inSidebar=this.inSidebar}}
    />
  </template>
}
