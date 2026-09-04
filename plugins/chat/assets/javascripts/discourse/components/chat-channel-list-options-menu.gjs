import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import {
  CHAT_CHANNEL_LIST_FILTERS,
  CHAT_CHANNEL_LIST_SORTS,
} from "discourse/plugins/chat/discourse/lib/chat-constants";
import ChatChannelListFilterMenu from "./chat-channel-list-filter-menu";
import ChatChannelListSortMenu from "./chat-channel-list-sort-menu";

const FILTER_LABEL_KEYS = {
  [CHAT_CHANNEL_LIST_FILTERS.ALL]: "chat.channel_list.filter.all",
  [CHAT_CHANNEL_LIST_FILTERS.ACTIVE]: "chat.channel_list.filter.active",
  [CHAT_CHANNEL_LIST_FILTERS.UNREAD]: "chat.channel_list.filter.unread",
  [CHAT_CHANNEL_LIST_FILTERS.MENTIONS]: "chat.channel_list.filter.mentions",
};

const SORT_LABEL_KEYS = {
  [CHAT_CHANNEL_LIST_SORTS.ALPHABETICAL]: "chat.channel_list.sort.alphabetical",
  [CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY]:
    "chat.channel_list.sort.recent_activity",
  [CHAT_CHANNEL_LIST_SORTS.PRIORITY]: "chat.channel_list.sort.priority",
};

export default class ChatChannelListOptionsMenu extends Component {
  @service chatChannelListPreferences;
  @service menu;
  @service router;

  get currentFilterLabel() {
    return i18n(FILTER_LABEL_KEYS[this.chatChannelListPreferences.filter]);
  }

  get currentFilterAriaLabel() {
    return i18n("chat.channel_list.options.current_filter", {
      filter: this.currentFilterLabel,
    });
  }

  get currentSortLabel() {
    return i18n(SORT_LABEL_KEYS[this.chatChannelListPreferences.sort]);
  }

  get currentSortAriaLabel() {
    return i18n("chat.channel_list.options.current_sort", {
      sort: this.currentSortLabel,
    });
  }

  get isFilterMenuExpanded() {
    return Boolean(
      this.menu.getByIdentifier("chat-channel-list-filter-menu")?.expanded
    );
  }

  get isSortMenuExpanded() {
    return Boolean(
      this.menu.getByIdentifier("chat-channel-list-sort-menu")?.expanded
    );
  }

  @action
  async browseChannels() {
    await Promise.all([
      this.menu.close("chat-channel-list-options-menu"),
      this.menu.close("chat-channel-list-filter-menu"),
      this.menu.close("chat-channel-list-sort-menu"),
    ]);
    await this.router.transitionTo("chat.browse.open");
  }

  @action
  openFilterMenu(_actionParam, event) {
    this.#openSubmenu(event, {
      component: ChatChannelListFilterMenu,
      identifier: "chat-channel-list-filter-menu",
    });
  }

  @action
  openSortMenu(_actionParam, event) {
    this.#openSubmenu(event, {
      component: ChatChannelListSortMenu,
      identifier: "chat-channel-list-sort-menu",
    });
  }

  #openSubmenu(event, { component, identifier }) {
    this.menu.show(event.currentTarget || event.target, {
      component,
      contentRole: "menu",
      groupIdentifier: "chat-channel-list-options-submenu",
      identifier,
      modalForMobile: true,
      offset: { mainAxis: 10, crossAxis: -5 },
      placement: "right-start",
    });
  }

  <template>
    <DDropdownMenu
      class="chat-channel-list-options-menu"
      role="none"
      as |dropdown|
    >
      <dropdown.item role="none">
        <DButton
          data-menu-option-id="browseChannels"
          role="menuitem"
          @action={{this.browseChannels}}
          @label="chat.channels_list_popup.browse"
        />
      </dropdown.item>

      <dropdown.divider role="none" />

      <dropdown.subheader role="presentation">
        {{i18n "chat.channel_list.options.filter"}}
      </dropdown.subheader>

      <dropdown.item role="none">
        <DButton
          aria-expanded={{if this.isFilterMenuExpanded "true" "false"}}
          aria-haspopup="menu"
          data-menu-option-id="filterChannels"
          role="menuitem"
          @action={{this.openFilterMenu}}
          @forwardEvent={{true}}
          @suffixIcon="angle-right"
          @translatedAriaLabel={{this.currentFilterAriaLabel}}
          @translatedLabel={{this.currentFilterLabel}}
        />
      </dropdown.item>

      <dropdown.subheader role="presentation">
        {{i18n "chat.channel_list.options.sort"}}
      </dropdown.subheader>

      <dropdown.item role="none">
        <DButton
          aria-expanded={{if this.isSortMenuExpanded "true" "false"}}
          aria-haspopup="menu"
          data-menu-option-id="sortChannels"
          role="menuitem"
          @action={{this.openSortMenu}}
          @forwardEvent={{true}}
          @suffixIcon="angle-right"
          @translatedAriaLabel={{this.currentSortAriaLabel}}
          @translatedLabel={{this.currentSortLabel}}
        />
      </dropdown.item>
    </DDropdownMenu>
  </template>
}
