import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatThreadList from "discourse/plugins/chat/discourse/components/chat-thread-list";

export default class ChatDrawerRoutesChannelThreads extends Component {
  @service chat;
  @service chatChannelsManager;
  @service chatStateManager;

  backLinkTitle = i18n("chat.return_to_list");

  get title() {
    return htmlSafe(
      i18n("chat.threads.list") +
        " - " +
        replaceEmoji(this.chat.activeChannel.title)
    );
  }

  @action
  async fetchChannel() {
    if (!this.args.params?.channelId) {
      return;
    }

    try {
      const channel = await this.chatChannelsManager.find(
        this.args.params.channelId
      );
      this.chat.activeChannel = channel;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="c-drawer-routes --channel-threads">
      {{#if this.chat.activeChannel}}
        <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
          <navbar.BackButton
            @title={{this.backLinkTitle}}
            @route="chat.channel"
            @routeModels={{this.chat.activeChannel.routeModels}}
          />
          <navbar.Title @title={{this.title}} @icon="discourse-threads" />
          <navbar.Actions as |a|>
            <a.ToggleDrawerButton />
            <a.FullPageButton />
            <a.CloseDrawerButton />
          </navbar.Actions>
        </Navbar>
      {{/if}}

      {{#if this.chatStateManager.isDrawerExpanded}}
        <div class="chat-drawer-content" {{didInsert this.fetchChannel}}>
          {{#if this.chat.activeChannel}}
            <ChatThreadList
              @channel={{this.chat.activeChannel}}
              @includeHeader={{false}}
            />
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
