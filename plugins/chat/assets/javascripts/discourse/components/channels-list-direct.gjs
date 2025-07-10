import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and, not, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import EmptyState from "discourse/components/empty-state";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";
import ChatChannelRow from "./chat-channel-row";
import ChatZero from "./svg/chat-zero";

export default class ChannelsListDirect extends Component {
  @service chat;
  @service chatChannelsManager;
  @service chatStateManager;
  @service currentUser;
  @service site;
  @service siteSettings;
  @service modal;

  get inSidebar() {
    return this.args.inSidebar ?? false;
  }

  get createDirectMessageChannelLabel() {
    if (!this.canCreateDirectMessageChannel) {
      return "chat.direct_messages.cannot_create";
    }

    return "chat.direct_messages.new";
  }

  get showDirectMessageChannels() {
    return (
      this.canCreateDirectMessageChannel || !this.directMessageChannelsEmpty
    );
  }

  get canCreateDirectMessageChannel() {
    return this.chat.userCanDirectMessage;
  }

  get directMessageChannelsEmpty() {
    return this.chatChannelsManager.directMessageChannels?.length === 0;
  }

  @action
  toggleChannelSection(section) {
    this.args.toggleSection(section);
  }

  @action
  openNewMessageModal() {
    this.modal.show(ChatModalNewMessage);
  }

  <template>
    {{#if
      (and
        this.showDirectMessageChannels
        (or
          this.site.desktopView
          (not this.chatChannelsManager.displayPublicChannels)
        )
      )
    }}
      <div class="chat-channel-divider direct-message-channels-section">
        {{#if this.inSidebar}}
          <span
            class="title-caret"
            id="direct-message-channels-caret"
            role="button"
            title="toggle nav list"
            {{on
              "click"
              (fn this.toggleChannelSection "direct-message-channels")
            }}
            data-toggleable="direct-message-channels"
          >
            {{icon "angle-up"}}
          </span>
        {{/if}}

        <span class="channel-title">{{i18n "chat.direct_messages.title"}}</span>

        {{#if this.canCreateDirectMessageChannel}}
          <DButton
            @icon="plus"
            class="no-text btn-flat open-new-message-btn"
            @action={{this.openNewMessageModal}}
            title={{i18n this.createDirectMessageChannelLabel}}
          />
        {{/if}}
      </div>
    {{/if}}

    <div
      id="direct-message-channels"
      class={{concatClass
        "channels-list-container"
        "direct-message-channels"
        (if this.inSidebar "collapsible-sidebar-section")
        (if this.directMessageChannelsEmpty "center-empty-channels-list")
      }}
    >
      {{#if this.directMessageChannelsEmpty}}
        <EmptyState
          @identifier="empty-channels-list"
          @svgContent={{ChatZero}}
          @title={{i18n "chat.no_direct_message_channels"}}
          @ctaLabel={{if
            this.canCreateDirectMessageChannel
            (i18n "chat.no_direct_message_channels_cta")
          }}
          @ctaAction={{this.openNewMessageModal}}
        />
      {{else}}
        {{#each
          this.chatChannelsManager.truncatedDirectMessageChannels
          as |channel|
        }}
          <ChatChannelRow
            @channel={{channel}}
            @options={{hash leaveButton=true}}
          />
        {{/each}}
      {{/if}}
    </div>

    <PluginOutlet
      @name="below-direct-chat-channels"
      @tagName=""
      @outletArgs={{lazyHash inSidebar=this.inSidebar}}
    />
  </template>
}
