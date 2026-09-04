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
  @service menu;

  @action
  async selectFilter(filter, event) {
    const trigger = this.menu.getByIdentifier(
      "chat-channel-list-options-menu"
    )?.triggerElement;
    await Promise.all([
      this.menu.close("chat-channel-list-filter-menu"),
      this.menu.close("chat-channel-list-options-menu"),
    ]);
    if (!this.menu.shouldRenderInModal(true) && event?.detail === 0) {
      trigger?.focus();
    }
    await this.chatChannelListPreferences.setFilter(filter);
  }

  <template>
    <DDropdownMenu
      aria-label={{i18n "chat.channel_list.filter.title"}}
      class="chat-channel-list-filter-menu"
      role="group"
      as |dropdown|
    >
      <dropdown.subheader role="presentation">
        {{i18n "chat.channel_list.filter.title"}}
      </dropdown.subheader>

      <dropdown.item role="none">
        <DButton
          aria-checked={{if
            (eq
              this.chatChannelListPreferences.filter
              CHAT_CHANNEL_LIST_FILTERS.ALL
            )
            "true"
            "false"
          }}
          class="chat-channel-list-filter-menu__all"
          data-menu-option-id="all"
          role="menuitemradio"
          @action={{this.selectFilter}}
          @actionParam={{CHAT_CHANNEL_LIST_FILTERS.ALL}}
          @disabled={{this.chatChannelListPreferences.isSavingFilter}}
          @icon="check"
          @label="chat.channel_list.filter.all"
        />
      </dropdown.item>

      <dropdown.item role="none">
        <DButton
          aria-checked={{if
            (eq
              this.chatChannelListPreferences.filter
              CHAT_CHANNEL_LIST_FILTERS.ACTIVE
            )
            "true"
            "false"
          }}
          class="chat-channel-list-filter-menu__active"
          data-menu-option-id="active"
          role="menuitemradio"
          @action={{this.selectFilter}}
          @actionParam={{CHAT_CHANNEL_LIST_FILTERS.ACTIVE}}
          @disabled={{this.chatChannelListPreferences.isSavingFilter}}
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
            (eq
              this.chatChannelListPreferences.filter
              CHAT_CHANNEL_LIST_FILTERS.UNREAD
            )
            "true"
            "false"
          }}
          class="chat-channel-list-filter-menu__unread"
          data-menu-option-id="unread"
          role="menuitemradio"
          @action={{this.selectFilter}}
          @actionParam={{CHAT_CHANNEL_LIST_FILTERS.UNREAD}}
          @disabled={{this.chatChannelListPreferences.isSavingFilter}}
          @icon="check"
          @label="chat.channel_list.filter.unread"
        />
      </dropdown.item>

      <dropdown.item role="none">
        <DButton
          aria-checked={{if
            (eq
              this.chatChannelListPreferences.filter
              CHAT_CHANNEL_LIST_FILTERS.MENTIONS
            )
            "true"
            "false"
          }}
          class="chat-channel-list-filter-menu__mentions"
          data-menu-option-id="mentions"
          role="menuitemradio"
          @action={{this.selectFilter}}
          @actionParam={{CHAT_CHANNEL_LIST_FILTERS.MENTIONS}}
          @disabled={{this.chatChannelListPreferences.isSavingFilter}}
          @icon="check"
          @label="chat.channel_list.filter.mentions"
        />
      </dropdown.item>
    </DDropdownMenu>
  </template>
}
