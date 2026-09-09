import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { CHAT_CHANNEL_LIST_SORTS } from "discourse/plugins/chat/discourse/lib/chat-constants";

export const SORT_OPTIONS = [
  {
    value: CHAT_CHANNEL_LIST_SORTS.ALPHABETICAL,
    className: "chat-channel-list-sort-menu__alphabetical",
    dataOptionId: "alphabetical",
    labelKey: "chat.channel_list.sort.alphabetical",
  },
  {
    value: CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY,
    className: "chat-channel-list-sort-menu__recent-activity",
    dataOptionId: "recent_activity",
    labelKey: "chat.channel_list.sort.recent_activity",
  },
  {
    value: CHAT_CHANNEL_LIST_SORTS.PRIORITY,
    className: "chat-channel-list-sort-menu__priority --with-description",
    dataOptionId: "priority",
    descriptionKey: "chat.channel_list.sort.priority_description",
    labelKey: "chat.channel_list.sort.priority",
  },
  {
    value: CHAT_CHANNEL_LIST_SORTS.UNREAD_FIRST,
    className: "chat-channel-list-sort-menu__unread-first --with-description",
    dataOptionId: "unread_first",
    descriptionKey: "chat.channel_list.sort.unread_first_description",
    labelKey: "chat.channel_list.sort.unread_first",
  },
];

/**
 * A single sort radio row for the channel list menus. Rendered either inside
 * the standalone sort menu (drawer, mobile, fly-out submenus) or inline in a
 * section header menu that has no other list options to fly out.
 */
export default class ChatChannelListSortChoice extends Component {
  @service chatChannelListPreferences;

  get isCurrentSort() {
    return (
      this.chatChannelListPreferences.sortFor(this.args.section) ===
      this.args.choice.value
    );
  }

  get isSavingSort() {
    return this.chatChannelListPreferences.isSavingSortFor(this.args.section);
  }

  @action
  async selectSort(sort) {
    const section = this.args.section;
    const preferences = this.chatChannelListPreferences;

    await this.args.closeSubmenu?.();
    await this.args.close?.();
    await this.args.closeParent?.();
    await preferences.setSort(section, sort);
  }

  <template>
    <li class="dropdown-menu__item chat-channel-list-sort-choice" role="none">
      <DButton
        aria-checked={{if this.isCurrentSort "true" "false"}}
        class={{@choice.className}}
        data-menu-option-id={{@choice.dataOptionId}}
        role="menuitemradio"
        @action={{this.selectSort}}
        @actionParam={{@choice.value}}
        @disabled={{this.isSavingSort}}
        @icon="check"
      >
        <span class="chat-channel-list-sort-menu__label">
          <span class="chat-channel-list-sort-menu__label-title">
            {{i18n @choice.labelKey}}
          </span>
          {{#if @choice.descriptionKey}}
            <span class="chat-channel-list-sort-menu__label-description">
              {{i18n @choice.descriptionKey}}
            </span>
          {{/if}}
        </span>
      </DButton>
    </li>
  </template>
}
