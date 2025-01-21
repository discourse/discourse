import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ChatPreferences extends Component {
  static shouldRender({ model }, { siteSettings, currentUser }) {
    return siteSettings.chat_enabled && (model.can_chat || currentUser?.admin);
  }

  <template>
    <li class="user-nav__preferences-chat">
      <LinkTo @route="preferences.chat">
        {{dIcon "d-chat"}}
        <span>{{i18n "chat.title_capitalized"}}</span>
      </LinkTo>
    </li>
  </template>
}
