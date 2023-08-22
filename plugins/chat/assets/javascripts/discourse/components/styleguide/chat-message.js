import Component from "@glimmer/component";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { action } from "@ember/object";
import ChatMessagesManager from "discourse/plugins/chat/discourse/lib/chat-messages-manager";
import { getOwner } from "discourse-common/lib/get-owner";
import { inject as service } from "@ember/service";

export default class ChatStyleguideChatMessage extends Component {
  @service currentUser;

  manager = new ChatMessagesManager(getOwner(this));

  constructor() {
    super(...arguments);
    this.message = fabricators.message({ user: this.currentUser });
    this.message.cook();
  }

  @action
  toggleDeleted() {
    if (this.message.deletedAt) {
      this.message.deletedAt = null;
    } else {
      this.message.deletedAt = moment();
    }
  }

  @action
  toggleBookmarked() {
    if (this.message.bookmark) {
      this.message.bookmark = null;
    } else {
      this.message.bookmark = fabricators.bookmark();
    }
  }

  @action
  toggleHighlighted() {
    this.message.highlighted = !this.message.highlighted;
  }

  @action
  toggleEdited() {
    this.message.edited = !this.message.edited;
  }

  @action
  toggleLastVisit() {
    this.message.newest = !this.message.newest;
  }

  @action
  toggleThread() {
    if (this.message.thread) {
      this.message.channel.threadingEnabled = false;
      this.message.thread = null;
    } else {
      this.message.thread = fabricators.thread({
        channel: this.message.channel,
      });
      this.message.thread.preview.replyCount = 1;
      this.message.channel.threadingEnabled = true;
    }
  }

  @action
  async updateMessage(event) {
    this.message.message = event.target.value;
    await this.message.cook();
  }

  @action
  toggleReaction() {
    if (this.message.reactions?.length) {
      this.message.reactions = [];
    } else {
      this.message.reactions = [
        fabricators.reaction({ emoji: "heart" }),
        fabricators.reaction({ emoji: "rocket", reacted: true }),
      ];
    }
  }

  @action
  toggleUpload() {
    if (this.message.uploads?.length) {
      this.message.uploads = [];
    } else {
      this.message.uploads = [fabricators.upload(), fabricators.upload()];
    }
  }
}
