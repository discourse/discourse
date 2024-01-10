import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { LinkTo } from "@ember/routing";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import noop from "discourse/helpers/noop";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import onResize from "../modifiers/chat/on-resize";
import ChatChannelRow from "./chat-channel-row";

export default class ChannelsListPublic extends Component {
  @service chatStateManager;
  @service chatChannelsManager;
  @service site;
  @service siteSettings;
  @service session;
  @service currentUser;

  @tracked hasScrollbar = false;

  @action
  computeHasScrollbar(element) {
    this.hasScrollbar = element.scrollHeight > element.clientHeight;
  }

  @action
  computeResizedEntries(entries) {
    this.computeHasScrollbar(entries[0].target);
  }

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
    return this.chatChannelsManager.publicMessageChannels.some(
      (channel) => channel.unreadThreadsCount > 0
    );
  }

  @action
  toggleChannelSection(section) {
    this.args.toggleSection(section);
  }

  didRender() {
    super.didRender(...arguments);

    schedule("afterRender", this._applyScrollPosition);
  }

  @action
  storeScrollPosition() {
    if (this.chatStateManager.isDrawerActive) {
      return;
    }

    const scrollTop = document.querySelector(".channels-list")?.scrollTop || 0;
    this.session.channelsListPosition = scrollTop;
  }

  @bind
  _applyScrollPosition() {
    if (this.chatStateManager.isDrawerActive) {
      return;
    }

    const position = this.chatStateManager.isFullPageActive
      ? this.session.channelsListPosition || 0
      : 0;
    const scroller = document.querySelector(".channels-list");
    scroller.scrollTo(0, position);
  }

  <template>
    <div
      role="region"
      aria-label={{i18n "chat.aria_roles.channels_list"}}
      class={{concatClass
        "channels-list"
        (if this.hasScrollbar "has-scrollbar")
      }}
      {{on
        "scroll"
        (if
          this.chatStateManager.isFullPageActive this.storeScrollPosition (noop)
        )
      }}
      {{didInsert this.computeHasScrollbar}}
      {{onResize this.computeResizedEntries}}
    >

      {{#if this.site.desktopView}}
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

        <div
          id="public-channels"
          class={{concatClass
            "channels-list-container"
            "public-channels"
            (if this.inSidebar "collapsible-sidebar-section")
          }}
        >
          {{#if this.publicChannelsEmpty}}
            <div class="public-channel-empty-message">
              <span class="channel-title">{{i18n
                  "chat.no_public_channels"
                }}</span>
              <LinkTo @route="chat.browse">
                {{i18n "chat.click_to_join"}}
              </LinkTo>
            </div>
          {{else}}
            {{#each
              this.chatChannelsManager.publicMessageChannels
              as |channel|
            }}
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
    </div>
  </template>
}
