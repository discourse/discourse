import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class ChatNavbarFilter extends Component {
  @service chatStateManager;

  <template>
    {{#unless this.chatStateManager.isDrawerCollapsed}}
      <DButton
        @icon="discourse-chat-search"
        @action={{@onToggleFilter}}
        class={{dConcatClass
          "btn-transparent c-navbar__filter"
          (if @isFiltering "active")
        }}
      />
    {{/unless}}
  </template>
}
