import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import { i18n } from "discourse-i18n";
import { CHAT_CHANNEL_LIST_FILTERS } from "discourse/plugins/chat/discourse/lib/chat-constants";
import ChatZero from "./svg/chat-zero";

/**
 * Shown when a chat channel list section is empty because its filter is
 * hiding every row. `@section` (`"channels"`, `"starred"`, or `"dms"`) picks
 * which section's filter the "show all" button resets. In the cover sidebar
 * the state is a slim section-list item; with `@layout="empty-state"` (used
 * by the drawer and mobile channel lists) it renders the same illustrated
 * empty state as the "no channels" DEmptyState so the two look alike.
 */
export default class ChatSidebarChannelListFilterEmptyState extends Component {
  @service chatChannelListPreferences;
  @service sidebarState;

  get section() {
    return this.args.section ?? "channels";
  }

  get isSaving() {
    return this.chatChannelListPreferences.isSavingFilterFor(this.section);
  }

  get isEmptyStateLayout() {
    return this.args.layout === "empty-state";
  }

  @action
  showAll() {
    return this.chatChannelListPreferences.setFilter(
      this.section,
      CHAT_CHANNEL_LIST_FILTERS.ALL
    );
  }

  <template>
    {{#unless this.sidebarState.filter}}
      {{#if this.isEmptyStateLayout}}
        <DEmptyState
          @identifier="empty-channels-list"
          @svgContent={{ChatZero}}
          @title={{i18n "chat.channel_list.empty.filtered"}}
          @ctaLabel={{i18n "chat.channel_list.empty.show_all"}}
          @ctaAction={{this.showAll}}
        />
      {{else}}
        <li class="chat-sidebar-channels-filter-empty-state" ...attributes>
          <span class="chat-sidebar-channels-filter-empty-state__text">
            {{i18n "chat.channel_list.empty.filtered"}}
          </span>
          <DButton
            class="btn-transparent chat-sidebar-channels-filter-empty-state__reset"
            @action={{this.showAll}}
            @disabled={{this.isSaving}}
            @label="chat.channel_list.empty.show_all"
          />
        </li>
      {{/if}}
    {{/unless}}
  </template>
}
