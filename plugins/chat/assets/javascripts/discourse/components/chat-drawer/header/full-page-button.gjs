import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class ChatDrawerHeaderFullPageButton extends Component {
  @service chatStateManager;

  <template>
    {{#if this.chatStateManager.isDrawerExpanded}}
      <DButton
        @icon="discourse-expand"
        class="btn-flat btn-link chat-drawer-header__full-screen-btn"
        @title="chat.open_full_page"
        @action={{@openInFullPage}}
      />
    {{/if}}
  </template>
}
