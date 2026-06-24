import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { isNone } from "@ember/utils";
import { prioritizeNameFallback } from "discourse/lib/settings";
import {
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  EDIT,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import { i18n } from "discourse-i18n";

export class ComposerActionItemBuilder {
  @service currentUser;
  @service site;
  @service composerActionState;
  @service composer;

  constructor(context, action, topic, post, replyOptions, composerModel) {
    setOwner(this, getOwner(context));

    this.action = action;
    this.topic = topic;
    this.post = post;
    this.replyOptions = replyOptions;
    this.composerModel = composerModel;
  }

  get isEditing() {
    return this.action === EDIT;
  }

  get snapshotPost() {
    return this.composerActionState.snapshot.post;
  }

  get snapshotTopic() {
    return this.composerActionState.snapshot.topic;
  }

  get isExistingTopic() {
    return !isNone(this.topic?.id);
  }

  get isCreatingTopic() {
    return this.action === CREATE_TOPIC || this.action === CREATE_SHARED_DRAFT;
  }

  build() {
    const items = [];

    if (this.isEditing) {
      return items;
    }

    // All of these items can be counted as a "maybe"
    // and will either return the item or null. Look at
    // the function itself for logic on whether the item
    // will be added to the list.
    items.push(this.#createSharedDraft());
    items.push(this.#createTopic());
    items.push(this.#replyToTopic());

    if (this.isExistingTopic) {
      items.push(this.#replyToPost());
      items.push(this.#replyAsNewTopic());
      items.push(this.#replyAsNewGroupMessage());
    }

    if (this.isCreatingTopic) {
      items.push(this.#replyToSnapshottedPost());
      items.push(this.#replyToSnapshottedTopic());
      items.push(this.#createPersonalMessage());
    }

    if (this.composer.canToggleWhisper) {
      items.push(this.#toggleWhisper());
    }

    if (this.composer.canToggleNoBump) {
      items.push(this.#toggleNoBump());
    }

    if (this.composer.canUnlistTopic) {
      items.push(this.#toggleUnlisted());
    }

    return items.filter(Boolean).flat();
  }

  // NOTE: Some duplication with ComposerActionsNew here...probably
  // fine but at some point we may want to consolidate.
  #postDisplayName(post) {
    const fallback = i18n("composer.composer_actions.unknown_user");
    if (!post) {
      return fallback;
    }
    if (post === this.post && this.replyOptions?.userLink?.anchor) {
      return this.replyOptions.userLink.anchor;
    }
    return prioritizeNameFallback(post.name, post.username) || fallback;
  }

  #replyAsNewTopic() {
    if (
      this.action === REPLY &&
      !this.topic.isPrivateMessage &&
      this.currentUser.can_create_topic
    ) {
      return {
        name: i18n("composer.composer_actions.reply_as_new_topic.label"),
        description: i18n("composer.composer_actions.reply_as_new_topic.desc"),
        icon: "far-pen-to-square",
        id: "reply_as_new_topic",
      };
    }
  }

  #replyAsNewGroupMessage() {
    if (
      this.action === REPLY &&
      this.topic.isPrivateMessage &&
      this.topic.details &&
      (this.topic.details.allowed_users?.length > 1 ||
        this.topic.details.allowed_groups?.length > 0)
    ) {
      return {
        name: i18n(
          "composer.composer_actions.reply_as_new_group_message.label"
        ),
        description: i18n(
          "composer.composer_actions.reply_as_new_group_message.desc"
        ),
        icon: "plus",
        id: "reply_as_new_group_message",
      };
    }
  }

  #replyToPost() {
    const canRestoreReplyToPost =
      this.action === REPLY &&
      !this.post &&
      this.snapshotPost &&
      this.snapshotTopic &&
      this.topic?.id === this.snapshotTopic.id;

    if (
      (this.action !== REPLY && this.post) ||
      (this.action === REPLY &&
        this.post &&
        !(this.replyOptions?.userAvatar && this.replyOptions?.userLink)) ||
      canRestoreReplyToPost
    ) {
      const postForLabel = this.post || this.snapshotPost;

      return {
        name: i18n("composer.composer_actions.reply_to_post.label", {
          postUsername: this.#postDisplayName(postForLabel),
        }),
        description: i18n("composer.composer_actions.reply_to_post.desc"),
        icon: "share",
        id: "reply_to_post",
      };
    }
  }

  #replyToTopic() {
    if (
      (this.action !== CREATE_TOPIC &&
        this.action !== PRIVATE_MESSAGE &&
        ((this.action !== REPLY && this.topic) ||
          (this.action === REPLY &&
            this.replyOptions?.userAvatar &&
            this.replyOptions?.userLink &&
            this.replyOptions?.topicLink))) ||
      (this.action === PRIVATE_MESSAGE && this.snapshotTopic)
    ) {
      const keyPrefix = (this.topic ?? this.snapshotTopic)?.isPrivateMessage
        ? "composer.composer_actions.reply_to_message"
        : "composer.composer_actions.reply_to_topic";
      return {
        name: i18n(`${keyPrefix}.label`),
        description: i18n(`${keyPrefix}.desc`),
        icon: "share",
        id: "reply_to_topic",
      };
    }
  }

  #replyToSnapshottedPost() {
    if (this.snapshotPost && this.snapshotTopic) {
      return {
        name: i18n("composer.composer_actions.reply_to_post.label", {
          postUsername: this.#postDisplayName(this.snapshotPost),
        }),
        description: i18n("composer.composer_actions.reply_to_post.desc"),
        icon: "share",
        id: "reply_to_post",
      };
    }
  }

  #replyToSnapshottedTopic() {
    if (this.snapshotTopic) {
      const keyPrefix = this.snapshotTopic?.isPrivateMessage
        ? "composer.composer_actions.reply_to_message"
        : "composer.composer_actions.reply_to_topic";
      return {
        name: i18n(`${keyPrefix}.label`),
        description: i18n(`${keyPrefix}.desc`),
        icon: "share",
        id: "reply_to_topic",
      };
    }
  }

  #createPersonalMessage() {
    if (this.currentUser?.can_send_private_messages) {
      return {
        name: i18n("composer.composer_actions.create_personal_message.label"),
        description: i18n(
          "composer.composer_actions.create_personal_message.desc"
        ),
        icon: "envelope",
        id: "create_private_message",
      };
    }
  }

  #createSharedDraft() {
    if (this.action === CREATE_TOPIC && this.site.shared_drafts_category_id) {
      return {
        name: i18n("composer.composer_actions.shared_draft.label"),
        description: i18n("composer.composer_actions.shared_draft.desc"),
        icon: "far-clipboard",
        id: "shared_draft",
      };
    }
  }

  #createTopic() {
    if (
      (this.action === CREATE_SHARED_DRAFT ||
        this.action === PRIVATE_MESSAGE) &&
      this.currentUser?.can_create_topic
    ) {
      return {
        name: i18n("composer.composer_actions.create_topic.label"),
        description: i18n("composer.composer_actions.create_topic.desc"),
        icon: "far-pen-to-square",
        id: "create_topic",
      };
    }
  }

  #toggleWhisper() {
    return {
      isToggle: true,
      action: () => this.composerModel.toggleProperty("whisper"),
      class: "composer-toggle-whisper",
      icon: "far-eye-slash",
      label: i18n("composer.composer_actions.toggle_whisper.label"),
      description: i18n("composer.composer_actions.toggle_whisper.desc"),
      state: this.composerModel.whisper,
      ariaLabel: i18n("composer.composer_actions.toggle_whisper.label"),
      id: "toggle_whisper",
    };
  }

  #toggleNoBump() {
    return {
      isToggle: true,
      action: () => this.composerModel.toggleProperty("noBump"),
      class: "composer-toggle-no-bump",
      icon: "anchor",
      label: i18n("composer.composer_actions.toggle_topic_bump.label"),
      description: i18n("composer.composer_actions.toggle_topic_bump.desc"),
      state: this.composerModel.noBump,
      ariaLabel: i18n("composer.composer_actions.toggle_topic_bump.label"),
      id: "toggle_topic_bump",
    };
  }

  #toggleUnlisted() {
    return {
      isToggle: true,
      action: () => this.composerModel.toggleProperty("unlistTopic"),
      class: "composer-toggle-unlisted",
      icon: "far-eye-slash",
      label: i18n("composer.composer_actions.toggle_unlisted.label"),
      description: i18n("composer.composer_actions.toggle_unlisted.desc"),
      state: this.composerModel.unlistTopic,
      ariaLabel: i18n("composer.composer_actions.toggle_unlisted.label"),
      id: "toggle_unlisted",
    };
  }
}
