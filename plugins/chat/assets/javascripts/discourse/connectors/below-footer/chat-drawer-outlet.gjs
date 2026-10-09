import Component from "@glimmer/component";
import { service } from "@ember/service";
import ChatDrawer from "../../components/chat-drawer";

class ChatDrawerOutlet extends Component {
  @service chatStateManager;

  <template>
    {{#if this.chatStateManager.canInteract}}
      <div class="below-footer-outlet chat-drawer-outlet">
        <div class="chat-drawer-outlet-container">
          <ChatDrawer />
        </div>
      </div>
    {{/if}}
  </template>
}

export default ChatDrawerOutlet;
