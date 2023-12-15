import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import replaceEmoji from "discourse/helpers/replace-emoji";
import I18n from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/navbar";

export default class ChatThreadListHeader extends Component {
  @service router;
  @service site;

  threadListTitle = I18n.t("chat.threads.list");

  get showBackButton() {
    return this.args.thread.channel && this.site.mobileView;
  }

  get backLink() {
    return {
      route: "chat.channel.index",
      models: this.args.thread.channel.routeModels,
      title: I18n.t("chat.return_to_channel"),
    };
  }

  <template>
    <Navbar as |navbar|>
      <navbar.BackButton />

      <navbar.Title
        @title={{replaceEmoji this.threadListTitle}}
        @icon="discourse-threads"
        as |title|
      >
        {{#if this.site.mobileView}}
          <title.SubTitle @title={{replaceEmoji @thread.channel.title}} />
        {{/if}}
      </navbar.Title>

      <navbar.Actions as |action|>
        <action.CloseThreadsButton @channel={{@thread.channel}} />
      </navbar.Actions>
    </Navbar>
  </template>
}
