import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatThreadList from "discourse/plugins/chat/discourse/components/chat-thread-list";

export default class ChatDrawerRoutesChannelThreads extends Component {
  @service chat;
  @service chatChannelsManager;

  backLinkTitle = I18n.t("chat.return_to_list");

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
    {{#if this.chat.activeChannel}}
      <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
        <navbar.BackButton
          @title={{this.backLinkTitle}}
          @route="chat.channel"
          @routeModels={{this.chat.activeChannel?.routeModels}}
        />
        <navbar.Title
          @title={{concat
            (i18n "chat.threads.list")
            " - "
            this.chat.activeChannel.title
          }}
          @icon="discourse-threads"
        />
        <navbar.Actions as |action|>
          <action.ThreadsListButton />
          <action.ToggleDrawerButton />
          <action.FullPageButton />
          <action.CloseDrawerButton />
        </navbar.Actions>
      </Navbar>
    {{/if}}

    <div class="chat-drawer-content" {{didInsert this.fetchChannel}}>
      {{#if this.chat.activeChannel}}
        <ChatThreadList
          @channel={{this.chat.activeChannel}}
          @includeHeader={{false}}
        />
      {{/if}}
    </div>
  </template>
}
