import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChannelInfoNav from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-nav";
import ChannelSettings from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-settings";

export default class ChatDrawerRoutesSettings extends Component {
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;

  get backButton() {
    return {
      route: "chat.channel",
      models: this.chat.activeChannel?.routeModels,
      title: i18n("chat.return_to_channel"),
    };
  }

  @action
  async fetchChannel() {
    if (!this.args.params?.channelId) {
      return;
    }

    const channel = await this.chatChannelsManager.find(
      this.args.params.channelId
    );

    this.chat.activeChannel = channel;
  }

  <template>
    <div
      class="c-drawer-routes --channel-info-settings"
      {{didInsert this.fetchChannel}}
    >
      {{#if this.chat.activeChannel}}
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
          <div class="chat-drawer-content">
            <ChannelInfoNav
              @channel={{this.chat.activeChannel}}
              @tab="settings"
            />
            <ChannelSettings @channel={{this.chat.activeChannel}} />
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
