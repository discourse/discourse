import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChannelInfoNav from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-nav";
import ChannelSearch from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-search";

export default class ChatDrawerRoutesSearch extends Component {
  @service chat;
  @service chatStateManager;

  get backButton() {
    return {
      route: "chat.channel",
      models: this.args.model?.channel?.routeModels,
      title: i18n("chat.return_to_channel"),
    };
  }

  <template>
    <div class="c-drawer-routes --channel-info-search">
      {{#if @model.channel}}
        <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
          <navbar.BackButton
            @title={{this.backButton.title}}
            @route={{this.backButton.route}}
            @routeModels={{this.backButton.models}}
          />
          <navbar.ChannelTitle @channel={{@model.channel}} />
          <navbar.Actions as |a|>
            <a.ToggleDrawerButton />
            <a.FullPageButton />
            <a.CloseDrawerButton />
          </navbar.Actions>
        </Navbar>

        {{#if this.chatStateManager.isDrawerExpanded}}
          <div class="chat-drawer-content">
            <ChannelInfoNav @channel={{@model.channel}} @tab="search" />
            <ChannelSearch @channel={{@model.channel}} />
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
