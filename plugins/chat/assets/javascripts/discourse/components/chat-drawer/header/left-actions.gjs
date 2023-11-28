import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";
import BackLink from "./back-link";

export default class ChatDrawerHeaderLeftActions extends Component {
  @service chatStateManager;

  <template>
    {{#if this.chatStateManager.isDrawerExpanded}}
      <div class="chat-drawer-header__left-actions">
        <div class="chat-drawer-header__top-line">
          <BackLink @route="chat" @title={{i18n "chat.return_to_list"}} />
        </div>
      </div>
    {{/if}}
  </template>
}
