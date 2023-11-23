import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { inject as service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";

export default class ChatDrawerHeader extends Component {
  @service chatStateManager;

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      role="region"
      aria-label={{i18n "chat.aria_roles.header"}}
      class="chat-drawer-header"
      {{on "click" @toggleExpand}}
      title={{if
        this.chatStateManager.isDrawerExpanded
        (i18n "chat.collapse")
        (i18n "chat.expand")
      }}
    >
      {{yield}}
    </div>
  </template>
}
