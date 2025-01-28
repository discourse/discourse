import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChannelMembers from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-members";
import ChannelInfoNav from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-nav";

export default class ChatDrawerRoutesMembers extends Component {
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
    <div class="c-drawer-routes --channel-info-members">
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
            <ChannelInfoNav @channel={{@model.channel}} @tab="members" />
            <ChannelMembers @channel={{@model.channel}} />
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
