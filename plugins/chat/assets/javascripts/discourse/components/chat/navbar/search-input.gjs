import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default class ChatNavbarSearchInput extends Component {
  @action
  trapFocus(event) {
    event.stopPropagation();
  }

  <template>
    <input
      value={{this.filter}}
      {{on "input" (withEventValue @onFilter)}}
      {{on "click" this.trapFocus}}
      placeholder={{i18n "chat.search_view.filter_placeholder"}}
      class="no-blur c-navbar__search-input"
      type="search"
    />
  </template>
}
