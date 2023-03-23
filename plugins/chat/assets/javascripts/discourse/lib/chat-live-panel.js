import { tracked } from "@glimmer/tracking";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { setOwner } from "@ember/application";
import { getOwner } from "discourse-common/lib/get-owner";

export default class ChatLivePanel {
  @service chat;
  @service chatChannelsManager;
  @service chatEmojiReactionStore;
  @service router;
  @service site;

  @tracked selectingMessages;
  @tracked lastSelectedMessage;
  @tracked hoveredMessageId;
  @tracked reacting;

  constructor(owner) {
    setOwner(this, owner);
  }

  get #model() {
    return this.chat.activeChannel;
  }

  get showMessageSeparators() {
    return true;
  }

  get messages() {
    return this.#model.messages;
  }

  get capabilities() {
    return getOwner(this).lookup("capabilities:main");
  }

  get selectedMessageIds() {
    return this.messages.filterBy("selected").mapBy("id");
  }

  findIndexOfMessage(message) {
    return this.messages.findIndex((m) => m.id === message.id);
  }

  onSelectMessage(message) {
    this.lastSelectedMessage = message;
    this.selectingMessages = true;
  }

  onReactMessage() {
    // creating reaction will create a membership if not present
    // so we will fully refresh if we were not members of the channel
    // already
    if (!this.#model.isFollowing || this.#model.isDraft) {
      return this.chatChannelsManager
        .getChannel(this.#model)
        .then((reactedChannel) => {
          this.router.transitionTo("chat.channel", "-", reactedChannel.id);
        });
    }
  }

  @action
  hoverMessage(message, options = {}, event) {
    if (this.site.mobileView && options.desktopOnly) {
      return;
    }

    if (message?.staged) {
      return;
    }

    if (
      this.hoveredMessageId &&
      message?.id &&
      this.hoveredMessageId === message?.id
    ) {
      return;
    }

    if (event) {
      if (
        event.type === "mouseleave" &&
        (event.toElement || event.relatedTarget)?.closest(
          ".chat-message-actions-desktop-anchor"
        )
      ) {
        return;
      }

      if (
        event.type === "mouseenter" &&
        (event.fromElement || event.relatedTarget)?.closest(
          ".chat-message-actions-desktop-anchor"
        )
      ) {
        this.hoveredMessageId = message?.id;
        return;
      }
    }

    this._onHoverMessageDebouncedHandler = discourseDebounce(
      this,
      this._debouncedOnHoverMessage,
      message,
      250
    );
  }

  @action
  cancelSelecting() {
    this.selectingMessages = false;
    this.lastSelectedMessage = null;
    this.messages.setEach("selected", false);
  }

  @bind
  _debouncedOnHoverMessage(message) {
    this.hoveredMessageId =
      message?.id && message.id !== this.hoveredMessageId ? message.id : null;
  }
}
