import {
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  EDIT,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import discourseComputed from "discourse-common/utils/decorators";
import Draft from "discourse/models/draft";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";
import bootbox from "bootbox";
import { camelize } from "@ember/string";
import { equal, gt } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";

// Component can get destroyed and lose state
let _topicSnapshot = null;
let _postSnapshot = null;
let _actionSnapshot = null;

export function _clearSnapshots() {
  _topicSnapshot = null;
  _postSnapshot = null;
  _actionSnapshot = null;
}

export default DropdownSelectBoxComponent.extend({
  seq: 0,
  pluginApiIdentifiers: ["composer-actions"],
  classNames: ["composer-actions"],
  isEditing: equal("action", EDIT),
  isInSlowMode: gt("topic.slow_mode_seconds", 0),

  selectKitOptions: {
    icon: "iconForComposerAction",
    filterable: false,
    showFullTitle: false,
    preventHeaderFocus: true,
    customStyle: true,
  },

  @discourseComputed("isEditing", "action", "whisper", "noBump", "isInSlowMode")
  iconForComposerAction(isEditing, action, whisper, noBump, isInSlowMode) {
    if (action === CREATE_TOPIC) {
      return "plus";
    } else if (action === PRIVATE_MESSAGE) {
      return "envelope";
    } else if (action === CREATE_SHARED_DRAFT) {
      return "far-clipboard";
    } else if (whisper) {
      return "far-eye-slash";
    } else if (noBump) {
      return "anchor";
    } else if (isInSlowMode) {
      return "hourglass-start";
    } else if (isEditing) {
      return "pencil-alt";
    } else {
      return "share";
    }
  },

  contentChanged() {
    this.set("seq", this.seq + 1);
  },

  didReceiveAttrs() {
    this._super(...arguments);
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
  },

  modifySelection() {
    return {};
  },

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
        name: I18n.t(
          "composer.composer_actions.reply_as_new_group_message.label"
        ),
        description: I18n.t(
          "composer.composer_actions.reply_as_new_group_message.desc"
        ),
        icon: "plus",
        id: "reply_as_new_group_message",
      });
    }

    if (
      this.action !== CREATE_TOPIC &&
      this.action !== CREATE_SHARED_DRAFT &&
      !(this.action === REPLY && this.topic && this.topic.isPrivateMessage) &&
      !this.isEditing &&
      _topicSnapshot
    ) {
      items.push({
        name: I18n.t("composer.composer_actions.reply_as_new_topic.label"),
        description: I18n.t(
          "composer.composer_actions.reply_as_new_topic.desc"
        ),
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
        name: I18n.t("composer.composer_actions.reply_to_post.label", {
          postUsername: _postSnapshot.username,
        }),
        description: I18n.t("composer.composer_actions.reply_to_post.desc"),
        icon: "share",
        id: "reply_to_post",
      });
    }

    if (
      this.siteSettings.enable_personal_messages &&
      this.action !== PRIVATE_MESSAGE &&
      !this.isEditing
    ) {
      items.push({
        name: I18n.t(
          "composer.composer_actions.reply_as_private_message.label"
        ),
        description: I18n.t(
          "composer.composer_actions.reply_as_private_message.desc"
        ),
        icon: "envelope",
        id: "reply_as_private_message",
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
        name: I18n.t("composer.composer_actions.reply_to_topic.label"),
        description: I18n.t("composer.composer_actions.reply_to_topic.desc"),
        icon: "share",
        id: "reply_to_topic",
      });
    }

    // if answered post is a whisper, we can only answer with a whisper so no need for toggle
    if (
      this.canWhisper &&
      (!_postSnapshot ||
        _postSnapshot.post_type !== this.site.post_types.whisper)
    ) {
      items.push({
        name: I18n.t("composer.composer_actions.toggle_whisper.label"),
        description: I18n.t("composer.composer_actions.toggle_whisper.desc"),
        icon: "far-eye-slash",
        id: "toggle_whisper",
      });
    }

    if (this.action === CREATE_TOPIC) {
      if (this.site.shared_drafts_category_id) {
        // Shared Drafts Choice
        items.push({
          name: I18n.t("composer.composer_actions.shared_draft.label"),
          description: I18n.t("composer.composer_actions.shared_draft.desc"),
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
        name: I18n.t("composer.composer_actions.toggle_topic_bump.label"),
        description: I18n.t("composer.composer_actions.toggle_topic_bump.desc"),
        icon: "anchor",
        id: "toggle_topic_bump",
      });
    }

    if (items.length === 0) {
      items.push({
        name: I18n.t("composer.composer_actions.create_topic.label"),
        description: I18n.t(
          "composer.composer_actions.reply_as_new_topic.desc"
        ),
        icon: "share",
        id: "create_topic",
      });
    }

    return items;
  },

  _replyFromExisting(options, post, topic) {
    this.closeComposer();
    this.openComposer(options, post, topic);
  },

  _openComposer(options) {
    this.closeComposer();
    this.openComposer(options);
  },

  toggleWhisperSelected(options, model) {
    model.toggleProperty("whisper");
  },

  toggleTopicBumpSelected(options, model) {
    model.toggleProperty("noBump");
  },

  replyAsNewGroupMessageSelected(options) {
    const recipients = [];

    const details = this.topic.details;
    details.allowed_users.forEach((u) => recipients.push(u.username));
    details.allowed_groups.forEach((g) => recipients.push(g.name));

    options.action = PRIVATE_MESSAGE;
    options.recipients = recipients.join(",");
    options.archetypeId = "private_message";
    options.skipDraftCheck = true;

    this._replyFromExisting(options, _postSnapshot, _topicSnapshot);
  },

  replyToTopicSelected(options) {
    options.action = REPLY;
    options.topic = _topicSnapshot;
    options.skipDraftCheck = true;
    this._openComposer(options);
  },

  replyToPostSelected(options) {
    options.action = REPLY;
    options.post = _postSnapshot;
    options.skipDraftCheck = true;
    this._openComposer(options);
  },

  replyAsNewTopicSelected(options) {
    Draft.get("new_topic").then((response) => {
      if (response.draft) {
        bootbox.confirm(
          I18n.t("composer.composer_actions.reply_as_new_topic.confirm"),
          (result) => {
            if (result) {
              this._replyAsNewTopicSelect(options);
            }
          }
        );
      } else {
        this._replyAsNewTopicSelect(options);
      }
    });
  },

  _replyAsNewTopicSelect(options) {
    options.action = CREATE_TOPIC;
    options.categoryId = this.get("composerModel.topic.category.id");
    options.disableScopedCategory = true;
    options.skipDraftCheck = true;
    this._replyFromExisting(options, _postSnapshot, _topicSnapshot);
  },

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
    options.skipDraftCheck = true;

    this._replyFromExisting(options, _postSnapshot, _topicSnapshot);
  },

  _switchCreate(options, action) {
    options.action = action;
    options.categoryId = this.get("composerModel.categoryId");
    options.topicTitle = this.get("composerModel.title");
    options.tags = this.get("composerModel.tags");
    options.skipDraftCheck = true;
    this._openComposer(options);
  },

  createTopicSelected(options) {
    this._switchCreate(options, CREATE_TOPIC);
  },

  sharedDraftSelected(options) {
    this._switchCreate(options, CREATE_SHARED_DRAFT);
  },

  actions: {
    onChange(value) {
      const action = `${camelize(value)}Selected`;
      if (this[action]) {
        this[action](
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
        console.error(`No method '${action}' found`);
      }
    },
  },
});
