import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import ThreadsListButton from "../../chat/thread/threads-list-button";
import CloseButton from "./close-button";
import FullPageButton from "./full-page-button";
import ToggleExpandButton from "./toggle-expand-button";

export default class ChatDrawerHeaderRightActions extends Component {
  @service chat;

  get showThreadsListButton() {
    return this.chat.activeChannel?.threadingEnabled;
  }

  <template>
    <div class="chat-drawer-header__right-actions">
      <div class="chat-drawer-header__top-line">
        {{#if this.showThreadsListButton}}
          <ThreadsListButton @channel={{this.chat.activeChannel}} />
        {{/if}}

        <ToggleExpandButton @toggleExpand={{@drawerActions.toggleExpand}} />

        <FullPageButton @openInFullPage={{@drawerActions.openInFullPage}} />

        <CloseButton @close={{@drawerActions.close}} />
      </div>
    </div>
  </template>
}
