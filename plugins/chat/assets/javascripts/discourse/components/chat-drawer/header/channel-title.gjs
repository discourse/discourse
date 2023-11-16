import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import ChatChannelTitle from "../../chat-channel-title";

export default class ChatDrawerChannelHeaderTitle extends Component {
  @service chatStateManager;

  <template>
    {{#if @channel}}
      {{#if this.chatStateManager.isDrawerExpanded}}
        <LinkTo
          @route={{if
            @channel.isDirectMessageChannel
            "chat.channel.info.settings"
            "chat.channel.info.members"
          }}
          @models={{@channel.routeModels}}
          class="chat-drawer-header__title"
        >
          <div class="chat-drawer-header__top-line">
            <ChatChannelTitle @channel={{@channel}} />
          </div>
        </LinkTo>
      {{else}}
        <div
          role="button"
          {{on "click" @drawerActions.toggleExpand}}
          class="chat-drawer-header__title"
        >
          <div class="chat-drawer-header__top-line">
            <ChatChannelTitle @channel={{@channel}}>
              {{#if @channel.tracking.unreadCount}}
                <span class="chat-unread-count">
                  {{@channel.tracking.unreadCount}}
                </span>
              {{/if}}
            </ChatChannelTitle>
          </div>
        </div>
      {{/if}}
    {{/if}}
  </template>
}
