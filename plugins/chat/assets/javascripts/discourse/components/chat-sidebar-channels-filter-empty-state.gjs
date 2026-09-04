import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { CHAT_CHANNEL_LIST_FILTERS } from "discourse/plugins/chat/discourse/lib/chat-constants";

export default class ChatSidebarChannelsFilterEmptyState extends Component {
  @service chatChannelListPreferences;
  @service sidebarState;

  @action
  showAllChannels() {
    return this.chatChannelListPreferences.setFilter(
      CHAT_CHANNEL_LIST_FILTERS.ALL
    );
  }

  <template>
    {{#unless this.sidebarState.filter}}
      <li class="chat-sidebar-channels-filter-empty-state" ...attributes>
        <span class="chat-sidebar-channels-filter-empty-state__text">
          {{i18n "chat.channel_list.empty.filtered"}}
        </span>
        <DButton
          class="btn-transparent chat-sidebar-channels-filter-empty-state__reset"
          @action={{this.showAllChannels}}
          @disabled={{this.chatChannelListPreferences.isSavingFilter}}
          @label="chat.channel_list.empty.show_all"
        />
      </li>
    {{/unless}}
  </template>
}
