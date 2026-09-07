import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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

  @action
  async browseChannels() {
    const router = this.router;
    await this.args.close?.();
    await router.transitionTo("chat.browse.open");
  }

  <template>
    <DDropdownMenu
      class="chat-channel-list-options-menu"
      role="none"
      ...attributes
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
        <DMenu
          aria-haspopup="menu"
          data-menu-option-id="filterChannels"
          role="menuitem"
          @ariaLabel={{this.currentFilterAriaLabel}}
          @contentRole="menu"
          @groupIdentifier="chat-channel-list-options-submenu"
          @identifier="chat-channel-list-filter-menu"
          @label={{this.currentFilterLabel}}
          @modalForMobile={{true}}
          @offset={{hash mainAxis=10 crossAxis=-5}}
          @placement="right-start"
        >
          <:trigger>
            <span class="d-button__suffix-icon">{{dIcon "angle-right"}}</span>
          </:trigger>
          <:content as |submenu|>
            <ChatChannelListFilterMenu
              @closeParent={{@close}}
              @closeSubmenu={{submenu.close}}
            />
          </:content>
        </DMenu>
      </dropdown.item>

      <dropdown.subheader role="presentation">
        {{i18n "chat.channel_list.options.sort"}}
      </dropdown.subheader>

      <dropdown.item role="none">
        <DMenu
          aria-haspopup="menu"
          data-menu-option-id="sortChannels"
          role="menuitem"
          @ariaLabel={{this.currentSortAriaLabel}}
          @contentRole="menu"
          @groupIdentifier="chat-channel-list-options-submenu"
          @identifier="chat-channel-list-sort-menu"
          @label={{this.currentSortLabel}}
          @modalForMobile={{true}}
          @offset={{hash mainAxis=10 crossAxis=-5}}
          @placement="right-start"
        >
          <:trigger>
            <span class="d-button__suffix-icon">{{dIcon "angle-right"}}</span>
          </:trigger>
          <:content as |submenu|>
            <ChatChannelListSortMenu
              @closeParent={{@close}}
              @closeSubmenu={{submenu.close}}
            />
          </:content>
        </DMenu>
      </dropdown.item>
    </DDropdownMenu>
  </template>
}
