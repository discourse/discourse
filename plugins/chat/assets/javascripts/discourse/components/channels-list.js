import { bind } from "discourse-common/utils/decorators";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
export default class ChannelsList extends Component {
  @service chat;
  @service router;
  @service chatStateManager;
  @service chatChannelsManager;
  @service site;
  @service session;
  @service currentUser;

  @tracked hasScrollbar = false;

  @action
  computeHasScrollbar(element) {
    this.hasScrollbar = element.scrollHeight > element.clientHeight;
  }

  @action
  computeResizedEntries(entries) {
    const element = entries[0].target;
    this.hasScrollbar = element.scrollHeight > element.clientHeight;
  }

  get showMobileDirectMessageButton() {
    return this.site.mobileView && this.showDirectMessageChannels;
  }

  get inSidebar() {
    return this.args.inSidebar ?? false;
  }

  get publicMessageChannelsEmpty() {
    return this.chatChannelsManager.publicMessageChannels?.length === 0;
  }

  get createDirectMessageChannelLabel() {
    if (!this.canCreateDirectMessageChannel) {
      return "chat.direct_messages.cannot_create";
    }

    return "chat.direct_messages.new";
  }

  get showDirectMessageChannels() {
    return (
      this.canCreateDirectMessageChannel ||
      this.chatChannelsManager.directMessageChannels?.length > 0
    );
  }

  get canCreateDirectMessageChannel() {
    return this.chat.userCanDirectMessage;
  }

  get publicChannelClasses() {
    return `channels-list-container public-channels ${
      this.inSidebar ? "collapsible-sidebar-section" : ""
    }`;
  }

  get displayPublicChannels() {
    if (this.publicMessageChannelsEmpty) {
      return (
        this.currentUser?.staff ||
        this.currentUser?.has_joinable_public_channels
      );
    }

    return true;
  }

  get directMessageChannelClasses() {
    return `channels-list-container direct-message-channels ${
      this.inSidebar ? "collapsible-sidebar-section" : ""
    }`;
  }

  @action
  toggleChannelSection(section) {
    this.args.toggleSection(section);
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
