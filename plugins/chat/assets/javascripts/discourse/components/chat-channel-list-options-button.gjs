import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { CHANNEL_LIST_SECTION_OPTIONS } from "discourse/plugins/chat/discourse/lib/chat-channel-list-options";
import ChatChannelListSidebarMenu from "./chat-channel-list-sidebar-menu.gjs";

/**
 * Divider/section header action that opens the shared channel list menu
 * (filter/sort/browse/create) for the given section. Used in the drawer,
 * mobile, and full-page channel lists, where a section header can't rely on
 * the cover sidebar's `actions` API.
 */
export default class ChatChannelListOptionsButton extends Component {
  @service menu;

  get section() {
    return this.args.section ?? "channels";
  }

  @action
  openMenu(_actionParam, event) {
    this.menu.show(event.target.closest("button"), {
      component: ChatChannelListSidebarMenu,
      contentRole: "menu",
      identifier: "chat-channel-list-options-menu",
      modalForMobile: true,
      placement: "right-start",
      data: {
        section: this.section,
        ...CHANNEL_LIST_SECTION_OPTIONS[this.section],
      },
    });
  }

  <template>
    <DButton
      class="chat-channel-list-options-button title-action"
      ...attributes
      @action={{this.openMenu}}
      @forwardEvent={{true}}
      @icon="ellipsis-vertical"
      @title="chat.channel_list.options.title"
    />
  </template>
}
