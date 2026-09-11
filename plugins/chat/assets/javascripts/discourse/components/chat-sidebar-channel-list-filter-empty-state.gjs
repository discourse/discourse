import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import { i18n } from "discourse-i18n";
import ChatZero from "./svg/chat-zero.gjs";

export default class ChatSidebarChannelListFilterEmptyState extends Component {
  @service chatChannelListPreferences;
  @service sidebarState;

  @action
  showAll() {
    this.chatChannelListPreferences.showAllChannels(
      this.args.section ?? "channels"
    );
  }

  <template>
    {{#unless this.sidebarState.filter}}
      <DEmptyState
        @ctaAction={{this.showAll}}
        @ctaLabel={{i18n "chat.channel_list.empty.show_all"}}
        @identifier="empty-channels-list"
        @svgContent={{ChatZero}}
        @title={{i18n "chat.channel_list.empty.filtered"}}
      />
    {{/unless}}
  </template>
}
