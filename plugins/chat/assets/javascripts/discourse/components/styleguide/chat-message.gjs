import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { optionalRequire } from "discourse/lib/utilities";
import ChatMessage from "discourse/plugins/chat/discourse/components/chat-message";
import ChatMessagesManager from "discourse/plugins/chat/discourse/lib/chat-messages-manager";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

const StyleguideComponent = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/component"
);
const Controls = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/controls"
);
const Row = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide/controls/row"
);
const StyleguideExample = optionalRequire(
  "discourse/plugins/styleguide/discourse/components/styleguide-example"
);

export default class ChatStyleguideChatMessage extends Component {
  @service currentUser;

  manager = new ChatMessagesManager(getOwner(this));

  constructor() {
    super(...arguments);
    this.message = new ChatFabricators(getOwner(this)).message({
      user: this.currentUser,
    });
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
      this.message.bookmark = new ChatFabricators(getOwner(this)).bookmark();
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
  toggleThread() {
    if (this.message.thread) {
      this.message.channel.threadingEnabled = false;
      this.message.thread = null;
    } else {
      this.message.thread = new ChatFabricators(getOwner(this)).thread({
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
        new ChatFabricators(getOwner(this)).reaction({ emoji: "heart" }),
        new ChatFabricators(getOwner(this)).reaction({
          emoji: "rocket",
          reacted: true,
        }),
      ];
    }
  }

  @action
  toggleUpload() {
    if (this.message.uploads?.length) {
      this.message.uploads = [];
    } else {
      this.message.uploads = [
        new ChatFabricators(getOwner(this)).upload(),
        new ChatFabricators(getOwner(this)).upload(),
      ];
    }
  }

  <template>
    <StyleguideExample @title="<ChatMessage>">
      <StyleguideComponent>
        <ChatMessage @message={{this.message}} @context="channel" />
      </StyleguideComponent>

      <Controls>
        <Row @name="Deleted">
          <DToggleSwitch
            @state={{not (not this.message.deletedAt)}}
            {{on "click" this.toggleDeleted}}
          />
        </Row>
        <Row @name="Bookmark">
          <DToggleSwitch
            @state={{not (not this.message.bookmark)}}
            {{on "click" this.toggleBookmarked}}
          />
        </Row>
        <Row @name="Thread">
          <DToggleSwitch
            @state={{not (not this.message.thread)}}
            {{on "click" this.toggleThread}}
          />
        </Row>
        <Row @name="Reactions">
          <DToggleSwitch
            @state={{not (not this.message.reactions)}}
            {{on "click" this.toggleReaction}}
          />
        </Row>
        <Row @name="Upload">
          <DToggleSwitch
            @state={{not (not this.message.uploads)}}
            {{on "click" this.toggleUpload}}
          />
        </Row>
        <Row @name="Message">
          <textarea
            {{on "input" this.updateMessage}}
          >{{this.message.message}}</textarea>
        </Row>
      </Controls>
    </StyleguideExample>
  </template>
}
