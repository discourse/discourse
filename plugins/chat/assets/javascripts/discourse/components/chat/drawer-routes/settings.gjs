import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChannelInfo from "discourse/plugins/chat/discourse/components/chat/routes/channel-info";
import ChannelSettings from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-settings";
import ChannelInfoNav from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-nav";

export default class ChatDrawerRoutesSettings extends Component {
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;

  get backButton() {
    return {
      route: "chat.channel",
      models: this.chat.activeChannel?.routeModels,
      title: I18n.t("chat.return_to_channel"),
    }
  }

  @action
  fetchChannel() {
    if (!this.args.params?.channelId) {
      return;
    }

    return this.chatChannelsManager
      .find(this.args.params.channelId)
      .then((channel) => {
        this.chat.activeChannel = channel;
      });
  }

  <template>
    <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
      <navbar.BackButton 
        @title={{this.backButton.title}} 
        @route={{this.backButton.route}} 
        @routeModels={{this.backButton.models}}
      />
      <navbar.ChannelTitle @channel={{this.chat.activeChannel}} />
      <navbar.Actions as |a|>
        <a.ToggleDrawerButton />
        <a.FullPageButton />
        <a.CloseDrawerButton />
      </navbar.Actions>
    </Navbar>

    {{#if this.chatStateManager.isDrawerExpanded}}
      <div
        class="chat-drawer-content"
        {{didInsert this.fetchChannel}}
        {{didUpdate this.fetchChannel @params.channelId}}
      >
        {{#if this.chat.activeChannel}}
          <ChannelInfoNav @channel={{this.chat.activeChannel}} @tab="settings" />
          <ChannelSettings @channel={{this.chat.activeChannel}} />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
