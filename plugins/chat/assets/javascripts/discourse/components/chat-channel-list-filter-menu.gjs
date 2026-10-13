import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import {
  CHAT_CHANNEL_LIST_ACTIVE_DAYS,
  CHAT_CHANNEL_LIST_FILTERS,
} from "discourse/plugins/chat/discourse/lib/chat-constants";

export default class ChatChannelListFilterMenu extends Component {
  @service chatChannelListPreferences;

  get section() {
    return this.args.section ?? "channels";
  }

  get currentFilter() {
    return this.chatChannelListPreferences.filterFor(this.section);
  }

  get isSaving() {
    return this.chatChannelListPreferences.isSavingFilterFor(this.section);
  }

  @action
  async selectFilter(filter) {
    const preferences = this.chatChannelListPreferences;
    const { closeParent, closeSubmenu } = this.args;
    const section = this.section;

    await closeSubmenu?.();
    await closeParent?.();
    await preferences.setFilter(section, filter);
  }

  <template>
    <DDropdownMenu
      aria-label={{i18n "chat.channel_list.filter.title"}}
      class="chat-channel-list-filter-menu"
      role="group"
      ...attributes
      as |dropdown|
    >
      <dropdown.subheader role="presentation">
        {{i18n "chat.channel_list.filter.title"}}
      </dropdown.subheader>

      <dropdown.item role="none">
        <DButton
          aria-checked={{if
            (eq this.currentFilter CHAT_CHANNEL_LIST_FILTERS.ALL)
            "true"
            "false"
          }}
          class="chat-channel-list-filter-menu__all"
          data-menu-option-id="all"
          role="menuitemradio"
          @action={{this.selectFilter}}
          @actionParam={{CHAT_CHANNEL_LIST_FILTERS.ALL}}
          @disabled={{this.isSaving}}
          @icon="check"
          @label="chat.channel_list.filter.all"
        />
      </dropdown.item>

      <dropdown.item role="none">
        <DButton
          aria-checked={{if
            (eq this.currentFilter CHAT_CHANNEL_LIST_FILTERS.ACTIVE)
            "true"
            "false"
          }}
          class="chat-channel-list-filter-menu__active --with-description"
          data-menu-option-id="active"
          role="menuitemradio"
          @action={{this.selectFilter}}
          @actionParam={{CHAT_CHANNEL_LIST_FILTERS.ACTIVE}}
          @disabled={{this.isSaving}}
          @icon="check"
        >
          <span class="chat-channel-list-filter-menu__label">
            <span class="chat-channel-list-filter-menu__label-title">
              {{i18n "chat.channel_list.filter.active"}}
            </span>
            <span class="chat-channel-list-filter-menu__label-description">
              {{i18n
                "chat.channel_list.filter.active_description"
                days=CHAT_CHANNEL_LIST_ACTIVE_DAYS
              }}
            </span>
          </span>
        </DButton>
      </dropdown.item>

      <dropdown.item role="none">
        <DButton
          aria-checked={{if
            (eq this.currentFilter CHAT_CHANNEL_LIST_FILTERS.UNREAD)
            "true"
            "false"
          }}
          class="chat-channel-list-filter-menu__unread"
          data-menu-option-id="unread"
          role="menuitemradio"
          @action={{this.selectFilter}}
          @actionParam={{CHAT_CHANNEL_LIST_FILTERS.UNREAD}}
          @disabled={{this.isSaving}}
          @icon="check"
          @label="chat.channel_list.filter.unread"
        />
      </dropdown.item>

      <dropdown.item role="none">
        <DButton
          aria-checked={{if
            (eq this.currentFilter CHAT_CHANNEL_LIST_FILTERS.MENTIONS)
            "true"
            "false"
          }}
          class="chat-channel-list-filter-menu__mentions"
          data-menu-option-id="mentions"
          role="menuitemradio"
          @action={{this.selectFilter}}
          @actionParam={{CHAT_CHANNEL_LIST_FILTERS.MENTIONS}}
          @disabled={{this.isSaving}}
          @icon="check"
          @label="chat.channel_list.filter.mentions"
        />
      </dropdown.item>
    </DDropdownMenu>
  </template>
}
