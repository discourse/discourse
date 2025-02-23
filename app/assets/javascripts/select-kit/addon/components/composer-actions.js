import { action } from "@ember/object";
import { equal, gt } from "@ember/object/computed";
import { service } from "@ember/service";
import { camelize } from "@ember/string";
import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import { escapeExpression } from "discourse/lib/utilities";
import {
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  EDIT,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import Draft from "discourse/models/draft";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";

// Component can get destroyed and lose state
let _topicSnapshot = null;
let _postSnapshot = null;
let _actionSnapshot = null;

export function _clearSnapshots() {
  _topicSnapshot = null;
  _postSnapshot = null;
  _actionSnapshot = null;
}

@classNames("composer-actions")
@pluginApiIdentifiers(["composer-actions"])
@selectKitOptions({
  icon: "iconForComposerAction",
  filterable: false,
  showFullTitle: false,
  preventHeaderFocus: true,
  customStyle: true,
})
export default class ComposerActions extends DropdownSelectBoxComponent {
  @service dialog;
  @service composer;

  seq = 0;

  @equal("action", EDIT) isEditing;
  @gt("topic.slow_mode_seconds", 0) isInSlowMode;

  @discourseComputed("isEditing", "action", "whisper", "noBump", "isInSlowMode")
  iconForComposerAction(
    isEditing,
    composerAction,
    whisper,
    noBump,
    isInSlowMode
  ) {
    if (composerAction === CREATE_TOPIC) {
      return "plus";
    } else if (composerAction === PRIVATE_MESSAGE) {
      return "envelope";
    } else if (composerAction === CREATE_SHARED_DRAFT) {
      return "far-clipboard";
    } else if (whisper) {
      return "far-eye-slash";
    } else if (noBump) {
      return "anchor";
    } else if (isInSlowMode) {
      return "hourglass-start";
    } else if (isEditing) {
      return "pencil";
    } else {
      return "share";
    }
  }

  contentChanged() {
    this.set("seq", this.seq + 1);
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    let changeContent = false;

    // if we change topic we want to change both snapshots
    if (
      this.topic &&
      (!_topicSnapshot || this.topic.id !== _topicSnapshot.id)
    ) {
      _topicSnapshot = this.topic;
      _postSnapshot = this.post;
      changeContent = true;
    }

    // if we hit reply on a different post we want to change postSnapshot
    if (this.post && (!_postSnapshot || this.post.id !== _postSnapshot.id)) {
      _postSnapshot = this.post;
      changeContent = true;
    }

    if (this.action !== _actionSnapshot) {
      _actionSnapshot = this.action;
      changeContent = true;
    }

    if (changeContent) {
      this.contentChanged();
    }

    this.set("selectKit.isHidden", isEmpty(this.content));
  }

  modifySelection() {
    return {};
  }

  @discourseComputed("seq")
  content() {
    let items = [];

    if (
      this.action === REPLY &&
      this.topic &&
      this.topic.isPrivateMessage &&
      this.topic.details &&
      (this.topic.details.allowed_users.length > 1 ||
        this.topic.details.allowed_groups.length > 0) &&
      !this.isEditing &&
      _topicSnapshot
    ) {
      items.push({
        name: i18n(
          "composer.composer_actions.reply_as_new_group_message.label"
        ),
        description: i18n(
          "composer.composer_actions.reply_as_new_group_message.desc"
        ),
        icon: "plus",
        id: "reply_as_new_group_message",
      });
    }

    if (
      this.action !== CREATE_TOPIC &&
      this.action !== CREATE_SHARED_DRAFT &&
      this.action === REPLY &&
      this.topic &&
      !this.topic.isPrivateMessage &&
      !this.isEditing &&
      this.currentUser.can_create_topic &&
      _topicSnapshot
    ) {
      items.push({
        name: i18n("composer.composer_actions.reply_as_new_topic.label"),
        description: i18n("composer.composer_actions.reply_as_new_topic.desc"),
        icon: "plus",
        id: "reply_as_new_topic",
      });
    }

    if (
      (this.action !== REPLY && _postSnapshot) ||
      (this.action === REPLY &&
        _postSnapshot &&
        !(this.replyOptions.userAvatar && this.replyOptions.userLink))
    ) {
      items.push({
        name: i18n("composer.composer_actions.reply_to_post.label", {
          postUsername: _postSnapshot.username,
        }),
        description: i18n("composer.composer_actions.reply_to_post.desc"),
        icon: "share",
        id: "reply_to_post",
      });
    }

    if (
      !this.isEditing &&
      ((this.action !== REPLY && _topicSnapshot) ||
        (this.action === REPLY &&
          _topicSnapshot &&
          this.replyOptions.userAvatar &&
          this.replyOptions.userLink &&
          this.replyOptions.topicLink))
    ) {
      items.push({
        name: i18n("composer.composer_actions.reply_to_topic.label"),
        description: i18n("composer.composer_actions.reply_to_topic.desc"),
        icon: "share",
        id: "reply_to_topic",
      });
    }

    // if answered post is a whisper, we can only answer with a whisper so no need for toggle
    if (
      this.canWhisper &&
      (!this.replyOptions.postLink ||
        !_postSnapshot ||
        _postSnapshot.post_type !== this.site.post_types.whisper)
    ) {
      items.push({
        name: i18n("composer.composer_actions.toggle_whisper.label"),
        description: i18n("composer.composer_actions.toggle_whisper.desc"),
        icon: "far-eye-slash",
        id: "toggle_whisper",
      });
    }

    if (this.action === CREATE_TOPIC) {
      if (this.site.shared_drafts_category_id) {
        // Shared Drafts Choice
        items.push({
          name: i18n("composer.composer_actions.shared_draft.label"),
          description: i18n("composer.composer_actions.shared_draft.desc"),
          icon: "far-clipboard",
          id: "shared_draft",
        });
      }
    }

    const showToggleTopicBump =
      this.get("currentUser.staff") ||
      this.get("currentUser.trust_level") === 4;

    if (this.action === REPLY && showToggleTopicBump) {
      items.push({
        name: i18n("composer.composer_actions.toggle_topic_bump.label"),
        description: i18n("composer.composer_actions.toggle_topic_bump.desc"),
        icon: "anchor",
        id: "toggle_topic_bump",
      });
    }

    if (items.length === 0 && this.currentUser.can_create_topic) {
      items.push({
        name: i18n("composer.composer_actions.create_topic.label"),
        description: i18n("composer.composer_actions.create_topic.desc"),
        icon: "share",
        id: "create_topic",
      });
    }

    return items;
  }

  _continuedFromText(post, topic) {
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

  _replyFromExisting(options, post, topic) {
    this.composer.closeComposer();
    this.composer.open({
      ...options,
      prependText: this._continuedFromText(post, topic),
    });
  }

  _openComposer(options) {
    this.composer.closeComposer();
    this.composer.open(options);
  }

  toggleWhisperSelected(options, model) {
    model.toggleProperty("whisper");
  }

  toggleTopicBumpSelected(options, model) {
    model.toggleProperty("noBump");
  }

  replyAsNewGroupMessageSelected(options) {
    const recipients = [];

    const details = this.topic.details;
    details.allowed_users.forEach((u) => recipients.push(u.username));
    details.allowed_groups.forEach((g) => recipients.push(g.name));

    options.action = PRIVATE_MESSAGE;
    options.recipients = recipients.join(",");
    options.archetypeId = "private_message";

    this._replyFromExisting(options, _postSnapshot, _topicSnapshot);
  }

  replyToTopicSelected(options) {
    options.action = REPLY;
    options.topic = _topicSnapshot;
    this._openComposer(options);
  }

  replyToPostSelected(options) {
    options.action = REPLY;
    options.post = _postSnapshot;
    this._openComposer(options);
  }

  replyAsNewTopicSelected(options) {
    Draft.get("new_topic").then((response) => {
      if (response.draft) {
        this.dialog.confirm({
          message: i18n("composer.composer_actions.reply_as_new_topic.confirm"),
          confirmButtonLabel: "composer.ok_proceed",
          didConfirm: () => this._replyAsNewTopicSelect(options),
        });
      } else {
        this._replyAsNewTopicSelect(options);
      }
    });
  }

  _replyAsNewTopicSelect(options) {
    options.action = CREATE_TOPIC;
    options.categoryId = this.get("composerModel.topic.category.id");
    options.disableScopedCategory = true;
    this._replyFromExisting(options, _postSnapshot, _topicSnapshot);
  }

  replyAsPrivateMessageSelected(options) {
    let usernames;

    if (_postSnapshot && !_postSnapshot.get("yours")) {
      const postUsername = _postSnapshot.get("username");
      if (postUsername) {
        usernames = postUsername;
      }
    } else if (this.get("composerModel.topic")) {
      const stream = this.get("composerModel.topic.postStream");

      if (stream.get("firstPostPresent")) {
        const post = stream.get("posts.firstObject");
        if (post && !post.get("yours") && post.get("username")) {
          usernames = post.get("username");
        }
      }
    }

    options.action = PRIVATE_MESSAGE;
    options.recipients = usernames;
    options.archetypeId = "private_message";

    this._replyFromExisting(options, _postSnapshot, _topicSnapshot);
  }

  _switchCreate(options, composerAction) {
    options.action = composerAction;
    options.categoryId = this.get("composerModel.categoryId");
    options.topicTitle = this.get("composerModel.title");
    options.tags = this.get("composerModel.tags");
    this._openComposer(options);
  }

  createTopicSelected(options) {
    this._switchCreate(options, CREATE_TOPIC);
  }

  sharedDraftSelected(options) {
    this._switchCreate(options, CREATE_SHARED_DRAFT);
  }

  @action
  onChange(value) {
    const composerAction = `${camelize(value)}Selected`;
    if (this[composerAction]) {
      this[composerAction](
        this.composerModel.getProperties(
          "draftKey",
          "draftSequence",
          "title",
          "reply",
          "disableScopedCategory"
        ),
        this.composerModel
      );
      this.contentChanged();
    } else {
      // eslint-disable-next-line no-console
      console.error(`No method '${composerAction}' found`);
    }
  }
}
