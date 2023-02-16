import { bind } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { and, empty } from "@ember/object/computed";

export default class ChannelsList extends Component {
  @service chat;
  @service router;
  @service chatStateManager;
  @service chatChannelsManager;
  tagName = "";
  inSidebar = false;
  toggleSection = null;
  @empty("chatChannelsManager.publicMessageChannels")
  publicMessageChannelsEmpty;
  @and("site.mobileView", "showDirectMessageChannels")
  showMobileDirectMessageButton;

  @computed("canCreateDirectMessageChannel")
  get createDirectMessageChannelLabel() {
    if (!this.canCreateDirectMessageChannel) {
      return "chat.direct_messages.cannot_create";
    }

    return "chat.direct_messages.new";
  }

  @computed(
    "canCreateDirectMessageChannel",
    "chatChannelsManager.directMessageChannels"
  )
  get showDirectMessageChannels() {
    return (
      this.canCreateDirectMessageChannel ||
      this.chatChannelsManager.directMessageChannels?.length > 0
    );
  }

  get canCreateDirectMessageChannel() {
    return this.chat.userCanDirectMessage;
  }

  @computed("inSidebar")
  get publicChannelClasses() {
    return `channels-list-container public-channels ${
      this.inSidebar ? "collapsible-sidebar-section" : ""
    }`;
  }

  @computed(
    "publicMessageChannelsEmpty",
    "currentUser.{staff,has_joinable_public_channels}"
  )
  get displayPublicChannels() {
    if (this.publicMessageChannelsEmpty) {
      return (
        this.currentUser?.staff ||
        this.currentUser?.has_joinable_public_channels
      );
    }

    return true;
  }

  @computed("inSidebar")
  get directMessageChannelClasses() {
    return `channels-list-container direct-message-channels ${
      this.inSidebar ? "collapsible-sidebar-section" : ""
    }`;
  }

  @action
  toggleChannelSection(section) {
    this.toggleSection(section);
  }

  didRender() {
    this._super(...arguments);

    schedule("afterRender", this._applyScrollPosition);
  }

  @action
  storeScrollPosition() {
    if (this.chatStateManager.isDrawerActive) {
      return;
    }

    const scrollTop = document.querySelector(".channels-list")?.scrollTop || 0;
    this.session.channelsListPosition = scrollTop;
  }

  @bind
  _applyScrollPosition() {
    if (this.chatStateManager.isDrawerActive) {
      return;
    }

    const position = this.chatStateManager.isFullPageActive
      ? this.session.channelsListPosition || 0
      : 0;
    const scroller = document.querySelector(".channels-list");
    scroller.scrollTo(0, position);
  }
}
