import Component from "@glimmer/component";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import and from "truth-helpers/helpers/and";
import or from "truth-helpers/helpers/or";
import ChatModalEditChannelName from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-name";
import ThreadsListButton from "discourse/plugins/chat/discourse/components/chat/thread/threads-list-button";
import ChatChannelStatus from "discourse/plugins/chat/discourse/components/chat-channel-status";
import ChatChannelTitle from "discourse/plugins/chat/discourse/components/chat-channel-title";

export default class ChatFullPageHeader extends Component {
  @service chatStateManager;
  @service modal;
  @service router;
  @service site;

  get displayed() {
    return this.args.displayed ?? true;
  }

  get showThreadsListButton() {
    return (
      this.args.channel.threadingEnabled &&
      this.router.currentRoute.name !== "chat.channel.threads" &&
      this.router.currentRoute.name !== "chat.channel.thread.index" &&
      this.router.currentRoute.name !== "chat.channel.thread"
    );
  }

  @action
  editChannelTitle() {
    return this.modal.show(ChatModalEditChannelName, {
      model: this.args.channel,
    });
  }

  <template>
    {{#if (and this.chatStateManager.isFullPageActive this.displayed)}}
      <div
        class={{concatClass
          "chat-full-page-header"
          (unless @channel.isFollowing "-not-following")
        }}
      >
        <div class="chat-channel-header-details">
          {{#if this.site.mobileView}}
            <div class="chat-full-page-header__left-actions">
              <LinkTo
                @route="chat"
                class="chat-full-page-header__back-btn no-text btn-flat"
              >
                {{icon "chevron-left"}}
              </LinkTo>
            </div>
          {{/if}}

          <LinkTo
            @route="chat.channel.info"
            @models={{@channel.routeModels}}
            class="chat-channel-title-wrapper"
          >
            <ChatChannelTitle @channel={{@channel}} />
          </LinkTo>

          {{#if (or @channel.threadingEnabled this.site.desktopView)}}
            <div class="chat-full-page-header__right-actions">
              {{#if this.site.desktopView}}
                <DButton
                  @icon="discourse-compress"
                  @title="chat.close_full_page"
                  class="open-drawer-btn btn-flat"
                  @action={{@onCloseFullScreen}}
                />
              {{/if}}

              {{#if this.showThreadsListButton}}
                <ThreadsListButton @channel={{@channel}} />
              {{/if}}
            </div>
          {{/if}}
        </div>
      </div>

      <ChatChannelStatus @channel={{@channel}} />
    {{/if}}
  </template>
}
