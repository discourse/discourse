import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import { CHAT_CHANNEL_LIST_SORTS } from "discourse/plugins/chat/discourse/lib/chat-constants";

export default class ChatChannelListSortMenu extends Component {
  @service chatChannelListPreferences;
  @service menu;

  @action
  async selectSort(sort, event) {
    const trigger = this.menu.getByIdentifier(
      "chat-channel-list-options-menu"
    )?.triggerElement;
    await Promise.all([
      this.menu.close("chat-channel-list-sort-menu"),
      this.menu.close("chat-channel-list-options-menu"),
    ]);
    if (!this.menu.shouldRenderInModal(true) && event?.detail === 0) {
      trigger?.focus();
    }
    await this.chatChannelListPreferences.setSort(sort);
  }

  <template>
    <DDropdownMenu
      aria-label={{i18n "chat.channel_list.sort.title"}}
      class="chat-channel-list-sort-menu"
      role="group"
      as |dropdown|
    >
      <dropdown.subheader role="presentation">
        {{i18n "chat.channel_list.sort.title"}}
      </dropdown.subheader>

      <dropdown.item role="none">
        <DButton
          aria-checked={{if
            (eq
              this.chatChannelListPreferences.sort
              CHAT_CHANNEL_LIST_SORTS.ALPHABETICAL
            )
            "true"
            "false"
          }}
          class="chat-channel-list-sort-menu__alphabetical"
          data-menu-option-id="alphabetical"
          role="menuitemradio"
          @action={{this.selectSort}}
          @actionParam={{CHAT_CHANNEL_LIST_SORTS.ALPHABETICAL}}
          @disabled={{this.chatChannelListPreferences.isSavingSort}}
          @icon="check"
          @label="chat.channel_list.sort.alphabetical"
        />
      </dropdown.item>

      <dropdown.item role="none">
        <DButton
          aria-checked={{if
            (eq
              this.chatChannelListPreferences.sort
              CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY
            )
            "true"
            "false"
          }}
          class="chat-channel-list-sort-menu__recent-activity"
          data-menu-option-id="recent_activity"
          role="menuitemradio"
          @action={{this.selectSort}}
          @actionParam={{CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY}}
          @disabled={{this.chatChannelListPreferences.isSavingSort}}
          @icon="check"
          @label="chat.channel_list.sort.recent_activity"
        />
      </dropdown.item>

      <dropdown.item role="none">
        <DButton
          aria-checked={{if
            (eq
              this.chatChannelListPreferences.sort
              CHAT_CHANNEL_LIST_SORTS.PRIORITY
            )
            "true"
            "false"
          }}
          class="chat-channel-list-sort-menu__priority"
          data-menu-option-id="priority"
          role="menuitemradio"
          @action={{this.selectSort}}
          @actionParam={{CHAT_CHANNEL_LIST_SORTS.PRIORITY}}
          @disabled={{this.chatChannelListPreferences.isSavingSort}}
          @icon="check"
        >
          <span class="chat-channel-list-sort-menu__label">
            <span class="chat-channel-list-sort-menu__label-title">
              {{i18n "chat.channel_list.sort.priority"}}
            </span>
            <span class="chat-channel-list-sort-menu__label-description">
              {{i18n "chat.channel_list.sort.priority_description"}}
            </span>
          </span>
        </DButton>
      </dropdown.item>
    </DDropdownMenu>
  </template>
}
