import Component from "@glimmer/component";
import { service } from "@ember/service";
import SidebarPanelPage from "discourse/components/sidebar/panel-page";
import { AI_CONVERSATIONS_PANEL } from "../services/ai-conversations-sidebar-manager.js";

// With the mobile tab bar, past conversations sit under the new conversation
// input instead of in the menu
export default class AiBotMobileConversationList extends Component {
  @service mobileTabBar;

  <template>
    {{#if this.mobileTabBar.enabled}}
      <div class="ai-bot-mobile-conversation-list">
        <SidebarPanelPage @panelKey={{AI_CONVERSATIONS_PANEL}} />
      </div>
    {{/if}}
  </template>
}
