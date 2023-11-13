import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class ChatDrawerHeaderToggleExpandButton extends Component {
  @service chatStateManager;

  <template>
    <DButton
      @icon={{if
        this.chatStateManager.isDrawerExpanded
        "angle-double-down"
        "angle-double-up"
      }}
      @action={{@toggleExpand}}
      @title={{if
        this.chatStateManager.isDrawerExpanded
        "chat.collapse"
        "chat.expand"
      }}
      class="btn-flat btn-link chat-drawer-header__expand-btn"
    />
  </template>
}
