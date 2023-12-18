import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import replaceEmoji from "discourse/helpers/replace-emoji";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";

export default class ChatThreadListHeader extends Component {
  @service router;
  @service site;

  threadListTitle = I18n.t("chat.threads.list");

  <template>
    <Navbar as |navbar|>
      <navbar.BackButton
        @route="chat.channel"
        @routeModels={{@channel.routeModels}}
        @title={{i18n "chat.return_to_channel"}}
      />

      <navbar.Title
        @title={{replaceEmoji this.threadListTitle}}
        @icon="discourse-threads"
        as |title|
      >
        {{#if this.site.mobileView}}
          <title.SubTitle @title={{replaceEmoji @channel.title}} />
        {{/if}}
      </navbar.Title>

      <navbar.Actions as |action|>
        <action.CloseThreadsButton @channel={{@channel}} />
      </navbar.Actions>
    </Navbar>
  </template>
}
