import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import EmberObject, { action } from "@ember/object";
import { not } from "@ember/object/computed";
import { service } from "@ember/service";
import { classNameBindings } from "@ember-decorators/component";
import { ajax } from "discourse/lib/ajax";
import { debounce } from "discourse/lib/decorators";
import LinkLookup from "discourse/lib/link-lookup";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { i18n } from "discourse-i18n";

let _messagesCache = {};

@classNameBindings(":composer-popup-container", "hidden")
export default class ComposerMessages extends Component {
  @service modal;
  @tracked showShareModal;

  checkedMessages = false;
  messages = null;
  messagesByTemplate = null;
  queuedForTyping = null;
  similarTopics = null;
  usersNotSeen = null;
  recipientNames = [];

  @not("composer.viewOpenOrFullscreen") hidden;

  _lastSimilaritySearch = null;
  _similarTopicsMessage = null;

  didInsertElement() {
    super.didInsertElement(...arguments);

    this.appEvents.on("composer:typed-reply", this, this._typedReply);
    this.appEvents.on("composer:opened", this, this._findMessages);
    this.appEvents.on("composer:find-similar", this, this._findSimilar);
    this.appEvents.on("composer-messages:close", this, this._closeTop);
    this.appEvents.on("composer-messages:create", this, this._create);
    this.reset();
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this.appEvents.off("composer:typed-reply", this, this._typedReply);
    this.appEvents.off("composer:opened", this, this._findMessages);
    this.appEvents.off("composer:find-similar", this, this._findSimilar);
    this.appEvents.off("composer-messages:close", this, this._closeTop);
    this.appEvents.off("composer-messages:create", this, this._create);
  }

  _closeTop() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.messages.popObject();
    this.set("messageCount", this.messages.length);
  }

  _removeMessage(message) {
    this.messages.removeObject(message);
    this.set("messageCount", this.messages.length);
  }

  _create(info) {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.reset();
    this.popup(EmberObject.create(info));
  }

  // Resets all active messages.
  // For example if composing a new post.
  reset() {
    this.setProperties({
      messages: [],
      messagesByTemplate: {},
      queuedForTyping: [],
      checkedMessages: false,
      similarTopics: [],
    });
  }

  // Called after the user has typed a reply.
  // Some messages only get shown after being typed.
  @debounce(INPUT_DELAY)
  async _typedReply() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    for (const msg of this.queuedForTyping) {
      if (this.composer.whisper && msg.hide_if_whisper) {
        return;
      }

      this.popup(msg);
    }

    if (this.composer.privateMessage) {
      if (
        this.composer.targetRecipientsArray.length > 0 &&
        this.composer.targetRecipientsArray.every(
          (r) => r.name === this.currentUser.username
        )
      ) {
        const message = this.composer.store.createRecord("composer-message", {
          id: "yourself_confirm",
          templateName: "education",
          title: i18n("composer.yourself_confirm.title"),
          body: i18n("composer.yourself_confirm.body"),
        });

        this.popup(message);
      }

      const recipient_names = this.composer.targetRecipientsArray
        .filter((r) => r.type === "user")
        .map(({ name }) => name);

      if (
        recipient_names.length > 0 &&
        recipient_names.length !== this.recipientNames.length &&
        !recipient_names.every((v, i) => v === this.recipientNames[i])
      ) {
        this.recipientNames = recipient_names;

        const response = await ajax(
          `/composer_messages/user_not_seen_in_a_while`,
          {
            type: "GET",
            data: {
              usernames: recipient_names,
            },
          }
        );

        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        if (
          response.user_count > 0 &&
          this.usersNotSeen !== response.usernames.join("-")
        ) {
          this.set("usersNotSeen", response.usernames.join("-"));
          this.messagesByTemplate["education"] = undefined;

          let usernames = [];
          response.usernames.forEach((username, index) => {
            usernames[
              index
            ] = `<a class='mention' href='/u/${username}'>@${username}</a>`;
          });

          let body_key;
          if (response.user_count === 1) {
            body_key = "composer.user_not_seen_in_a_while.single";
          } else {
            body_key = "composer.user_not_seen_in_a_while.multiple";
          }

          const message = this.composer.store.createRecord("composer-message", {
            id: "user-not-seen",
            templateName: "education",
            body: i18n(body_key, {
              usernames: usernames.join(", "),
              time_ago: response.time_ago,
            }),
          });

          this.popup(message);
        }
      }
    }
  }

  async _findSimilar() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    // We don't care about similar topics unless creating a topic
    if (!this.composer.creatingTopic) {
      return;
    }

    // We don't care about similar topics when creating with a form template
    if (this.composer?.category?.form_template_ids.length > 0) {
      return;
    }

    // TODO: pass the 200 in from somewhere
    const raw = (this.composer.reply || "").slice(0, 200);
    const title = this.composer.title || "";

    // Ensure we have at least a title
    if (title.length < this.siteSettings.min_title_similar_length) {
      return;
    }

    // Don't search over and over
    const concat = title + raw;
    if (concat === this._lastSimilaritySearch) {
      return;
    }

    this._lastSimilaritySearch = concat;
    this._similarTopicsMessage ||= this.composer.store.createRecord(
      "composer-message",
      {
        id: "similar_topics",
        templateName: "similar-topics",
        extraClass: "similar-topics",
      }
    );

    const topics = await this.composer.store.find("similar-topic", {
      title,
      raw,
    });

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.similarTopics.clear();
    this.similarTopics.pushObjects(topics.content);

    if (this.similarTopics.length > 0) {
      this._similarTopicsMessage.set("similarTopics", this.similarTopics);
      this.popup(this._similarTopicsMessage);
    } else if (this._similarTopicsMessage) {
      this.hideMessage(this._similarTopicsMessage);
    }
  }

  // Figure out if there are any messages that should be displayed above the composer.
  async _findMessages() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (this.checkedMessages) {
      return;
    }

    const args = { composer_action: this.composer.action };
    const topicId = this.composer.topic?.id;
    const postId = this.composer.post?.id;

    if (topicId) {
      args.topic_id = topicId;
    }

    if (postId) {
      args.post_id = postId;
    }

    const cacheKey = `${args.composer_action}${args.topic_id}${args.post_id}`;

    let messages;
    if (_messagesCache.cacheKey === cacheKey) {
      messages = _messagesCache.messages;
    } else {
      messages = await this.composer.store.find("composer-message", args);
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      _messagesCache = { messages, cacheKey };
    }

    // Checking composer messages on replies can give us a list of links to check for
    // duplicates
    if (messages.extras?.duplicate_lookup) {
      this.addLinkLookup(new LinkLookup(messages.extras.duplicate_lookup));
    }

    this.set("checkedMessages", true);

    messages.forEach((msg) => {
      if (msg.wait_for_typing) {
        this.queuedForTyping.addObject(msg);
      } else {
        this.popup(msg);
      }
    });
  }

  @action
  closeMessage(message, event) {
    event?.preventDefault();
    this._removeMessage(message);
  }

  @action
  hideMessage(message) {
    this._removeMessage(message);

    // kind of hacky but the visibility depends on this
    this.messagesByTemplate[message.templateName] = undefined;
  }

  @action
  popup(message) {
    if (!this.messagesByTemplate[message.templateName]) {
      this.messages.pushObject(message);
      this.set("messageCount", this.messages.length);
      this.messagesByTemplate[message.templateName] = message;
    }
  }

  get shareModalData() {
    const { topic } = this.composer;
    return {
      topic,
      category: topic.category,
      allowInvites:
        topic.details.can_invite_to &&
        !topic.archived &&
        !topic.closed &&
        !topic.deleted,
    };
  }

  @action
  switchPM(message) {
    this.composer.set("action", "privateMessage");
    this.composer.set("targetRecipients", message.reply_username);
    this._removeMessage(message);
  }
}
