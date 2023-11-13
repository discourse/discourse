import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";
import ChannelsList from "../channels-list";
import Header from "./header";
import RightActions from "./header/right-actions";

export default class ChatDrawerIndex extends Component {
  @service chatStateManager;

  <template>
    <Header @toggleExpand={{@drawerActions.toggleExpand}}>
      <div class="chat-drawer-header__title">
        <div class="chat-drawer-header__top-line">
          {{i18n "chat.heading"}}
        </div>
      </div>

      <RightActions @drawerActions={{@drawerActions}} />
    </Header>

    {{#if this.chatStateManager.isDrawerExpanded}}
      <div class="chat-drawer-content">
        <ChannelsList />
      </div>
    {{/if}}
  </template>
}
