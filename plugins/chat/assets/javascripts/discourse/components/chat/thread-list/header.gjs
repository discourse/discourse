import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";

export default class ChatThreadListHeader extends Component {
  @service router;
  @service site;

  threadListTitle = i18n("chat.threads.list");

  get title() {
    let title = replaceEmoji(this.threadListTitle);

    if (this.site.mobileView) {
      title += " - " + replaceEmoji(this.args.channel.title);
    }

    return htmlSafe(title);
  }

  <template>
    <Navbar as |navbar|>
      {{#if this.site.mobileView}}
        <navbar.BackButton
          @route="chat.channel"
          @routeModels={{@channel.routeModels}}
          @title={{i18n "chat.return_to_channel"}}
        />
      {{/if}}

      <navbar.Title @title={{this.title}} @icon="discourse-threads" />

      <navbar.Actions as |action|>
        <action.CloseThreadsButton @channel={{@channel}} />
      </navbar.Actions>
    </Navbar>
  </template>
}
