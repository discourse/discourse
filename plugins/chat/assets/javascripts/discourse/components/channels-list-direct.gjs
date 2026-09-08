import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { and, not, or } from "discourse/truth-helpers";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";
import ChatChannelListOptionsButton from "./chat-channel-list-options-button";
import ChatChannelRow from "./chat-channel-row";
import ChatSidebarChannelListFilterEmptyState from "./chat-sidebar-channel-list-filter-empty-state";
import ChatZero from "./svg/chat-zero";

export default class ChannelsListDirect extends Component {
  @service chat;
  @service chatChannelsManager;
  @service site;
  @service modal;

  get inSidebar() {
    return this.args.inSidebar ?? false;
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

  get channelList() {
    if (this.inSidebar) {
      return this.chatChannelsManager.sidebarDirectMessageChannels;
    }
    // In mobile/drawer, show all channels including starred, sorted by preference
    return this.chatChannelsManager.truncatedDirectMessageChannelsByPreference;
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
            {{dIcon "angle-up"}}
          </span>
        {{/if}}

        <span class="channel-title">{{i18n "chat.direct_messages.title"}}</span>

        {{#if this.site.desktopView}}
          <div class="chat-channel-divider__actions">
            <ChatChannelListOptionsButton @section="dms" />
          </div>
        {{/if}}
      </div>
    {{/if}}

    <div
      id="direct-message-channels"
      class={{dConcatClass
        "channels-list-container"
        "direct-message-channels"
        (if this.inSidebar "collapsible-sidebar-section")
        (if this.directMessageChannelsEmpty "center-empty-channels-list")
      }}
    >
      {{#if this.directMessageChannelsEmpty}}
        <DEmptyState
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
        {{#each this.channelList as |channel|}}
          <ChatChannelRow
            @channel={{channel}}
            @options={{hash leaveButton=true}}
          />
        {{else}}
          {{#unless this.inSidebar}}
            <ChatSidebarChannelListFilterEmptyState
              @layout="empty-state"
              @section="dms"
            />
          {{/unless}}
        {{/each}}
      {{/if}}
    </div>

    <PluginOutlet
      @name="below-direct-chat-channels"
      @outletArgs={{lazyHash inSidebar=this.inSidebar}}
    />
  </template>
}
