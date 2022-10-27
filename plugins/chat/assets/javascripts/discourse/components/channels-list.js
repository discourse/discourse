import { bind } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { and, empty, reads } from "@ember/object/computed";
import { DRAFT_CHANNEL_VIEW } from "discourse/plugins/chat/discourse/services/chat";

export default class ChannelsList extends Component {
  @service chat;
  @service router;
  tagName = "";
  inSidebar = false;
  toggleSection = null;
  onSelect = null;
  @reads("chat.publicChannels.[]") publicChannels;
  @reads("chat.directMessageChannels.[]") directMessageChannels;
  @empty("publicChannels") publicChannelsEmpty;
  @and("site.mobileView", "showDirectMessageChannels")
  showMobileDirectMessageButton;

  @computed("canCreateDirectMessageChannel")
  get createDirectMessageChannelLabel() {
    if (!this.canCreateDirectMessageChannel) {
      return "chat.direct_messages.cannot_create";
    }

    return "chat.direct_messages.new";
  }

  @computed("canCreateDirectMessageChannel", "directMessageChannels")
  get showDirectMessageChannels() {
    return (
      this.canCreateDirectMessageChannel ||
      this.directMessageChannels?.length > 0
    );
  }

  get canCreateDirectMessageChannel() {
    return this.chat.userCanDirectMessage;
  }

  @computed("directMessageChannels.@each.last_message_sent_at")
  get sortedDirectMessageChannels() {
    if (!this.directMessageChannels?.length) {
      return [];
    }

    return this.chat.truncateDirectMessageChannels(
      this.chat.sortDirectMessageChannels(this.directMessageChannels)
    );
  }

  @computed("inSidebar")
  get publicChannelClasses() {
    return `channels-list-container public-channels ${
      this.inSidebar ? "collapsible-sidebar-section" : ""
    }`;
  }

  @computed(
    "publicChannelsEmpty",
    "currentUser.{staff,has_joinable_public_channels}"
  )
  get displayPublicChannels() {
    if (this.publicChannelsEmpty) {
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
  browseChannels() {
    this.router.transitionTo("chat.browse");
    return false;
  }

  @action
  startCreatingDmChannel() {
    if (
      this.site.mobileView ||
      this.router.currentRouteName.startsWith("chat.")
    ) {
      this.router.transitionTo("chat.draft-channel");
    } else {
      this.appEvents.trigger("chat:open-view", DRAFT_CHANNEL_VIEW);
    }
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
    const scroller = document.querySelector(".channels-list");
    if (scroller) {
      const scrollTop = scroller.scrollTop || 0;
      this.session.set("channels-list-position", scrollTop);
    }
  }

  @bind
  _applyScrollPosition() {
    const data = this.session.get("channels-list-position");
    if (data) {
      const scroller = document.querySelector(".channels-list");
      scroller.scrollTo(0, data);
    }
  }
}
