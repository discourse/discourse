import Service, { service } from "@ember/service";
import { escapeExpression } from "discourse/lib/utilities";
import {
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import Draft from "discourse/models/draft";
import { i18n } from "discourse-i18n";

export default class ComposerActionStateService extends Service {
  @service composer;
  @service dialog;

  topicSnapshot = null;
  postSnapshot = null;

  remember({ topic, post }) {
    if (topic && (!this.topicSnapshot || topic.id !== this.topicSnapshot.id)) {
      this.topicSnapshot = topic;
      this.postSnapshot = post;
    }

    if (post && (!this.postSnapshot || post.id !== this.postSnapshot.id)) {
      this.postSnapshot = post;
    }
  }

  clear() {
    this.topicSnapshot = null;
    this.postSnapshot = null;
  }

  get snapshot() {
    return { topic: this.topicSnapshot, post: this.postSnapshot };
  }

  async selectAction(actionId, { options, composerModel, topic, post }) {
    this.remember({ topic, post });

    switch (actionId) {
      case "reply_as_new_group_message":
        await this.replyAsNewGroupMessageSelected(options, topic);
        return true;
      case "reply_as_new_topic":
        await this.replyAsNewTopicSelected(options, composerModel);
        return true;
      case "reply_to_post":
        await this.replyToPostSelected(options);
        return true;
      case "reply_to_topic":
        await this.replyToTopicSelected(options);
        return true;
      case "shared_draft":
        await this.sharedDraftSelected(options, composerModel);
        return true;
      case "create_topic":
        await this.createTopicSelected(options, composerModel);
        return true;
      case "create_private_message":
        await this.createPrivateMessageSelected(options, composerModel);
        return true;
      default:
        return false;
    }
  }

  async replyAsNewGroupMessageSelected(options, topic) {
    const recipients = [];
    const details = topic.details;
    details.allowed_users.forEach((u) => recipients.push(u.username));
    details.allowed_groups.forEach((g) => recipients.push(g.name));

    options.action = PRIVATE_MESSAGE;
    options.recipients = recipients.join(",");
    options.archetypeId = "private_message";

    await this.#replyFromExisting(
      options,
      this.postSnapshot,
      this.topicSnapshot
    );
  }

  async replyAsNewTopicSelected(options, composerModel) {
    const response = await Draft.get("new_topic");

    if (response.draft) {
      this.dialog.confirm({
        message: i18n("composer.composer_actions.reply_as_new_topic.confirm"),
        confirmButtonLabel: "composer.ok_proceed",
        didConfirm: () => this.#replyAsNewTopicSelect(options, composerModel),
      });
    } else {
      await this.#replyAsNewTopicSelect(options, composerModel);
    }
  }

  async replyToPostSelected(options) {
    options.action = REPLY;
    options.post = this.postSnapshot;
    await this.#openComposer(options);
  }

  async replyToTopicSelected(options) {
    options.action = REPLY;
    options.topic = this.topicSnapshot;
    await this.#openComposer(options);
  }

  async sharedDraftSelected(options, composerModel) {
    await this.#switchCreate(options, CREATE_SHARED_DRAFT, composerModel);
  }

  async createTopicSelected(options, composerModel) {
    await this.#switchCreate(options, CREATE_TOPIC, composerModel);
  }

  async createPrivateMessageSelected(options, composerModel) {
    options.archetypeId = "private_message";
    await this.#switchCreate(options, PRIVATE_MESSAGE, composerModel);
  }

  async #replyAsNewTopicSelect(options, composerModel) {
    options.action = CREATE_TOPIC;
    options.draftKey = this.composer.topicDraftKey;
    options.categoryId = composerModel.topic?.category?.id;
    options.disableScopedCategory = true;

    await this.#replyFromExisting(
      options,
      this.postSnapshot,
      this.topicSnapshot
    );
  }

  async #switchCreate(options, composerAction, composerModel) {
    options.action = composerAction;
    options.categoryId = composerModel.categoryId;
    options.topicTitle = composerModel.title;
    options.tags = composerModel.tags;
    await this.#openComposer(options);
  }

  #continuedFromText(post, topic) {
    let url = post?.url || topic?.url;
    const topicTitle = topic?.title;

    if (!url || !topicTitle) {
      return;
    }

    url = `${location.protocol}//${location.host}${url}`;
    const link = `[${escapeExpression(topicTitle)}](${url})`;
    return i18n("post.continue_discussion", {
      postLink: link,
    });
  }

  async #replyFromExisting(options, post, topic) {
    const snapshot = this.snapshot;

    this.#clearUnsupportedToggles(options);
    await this.composer.destroyDraft();
    this.composer.close();
    this.#restoreSnapshot(snapshot);
    await this.composer.open({
      ...options,
      prependText: this.#continuedFromText(post, topic),
    });
    this.#reapplyToggles(options);
  }

  async #openComposer(options) {
    const snapshot = this.snapshot;

    this.#clearUnsupportedToggles(options);
    this.composer.closeComposer();
    this.#restoreSnapshot(snapshot);
    await this.composer.open(options);
    this.#reapplyToggles(options);
  }

  #restoreSnapshot({ topic, post }) {
    this.topicSnapshot = topic;
    this.postSnapshot = post;
  }

  #clearUnsupportedToggles(options) {
    if (options.action !== REPLY) {
      options.whisper = false;
      options.noBump = false;
    }

    if (options.action !== CREATE_TOPIC) {
      options.unlistTopic = false;
    }
  }

  #reapplyToggles(options) {
    const model = this.composer.model;
    if (!model) {
      return;
    }

    if (model.creatingTopic && options.unlistTopic) {
      model.set("unlistTopic", true);
    }

    if (model.replyingToTopic && options.whisper) {
      model.set("whisper", true);
    }

    if (model.replyingToTopic && options.noBump) {
      model.set("noBump", true);
    }
  }
}
