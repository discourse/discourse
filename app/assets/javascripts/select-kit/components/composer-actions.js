import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import {
  PRIVATE_MESSAGE,
  CREATE_TOPIC,
  CREATE_SHARED_DRAFT,
  REPLY
} from "discourse/models/composer";
import Draft from "discourse/models/draft";
import { computed } from "@ember/object";
import { camelize } from "@ember/string";
import { isEmpty } from "@ember/utils";

// Component can get destroyed and lose state
let _topicSnapshot = null;
let _postSnapshot = null;

export function _clearSnapshots() {
  _topicSnapshot = null;
  _postSnapshot = null;
}

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["composer-actions"],
  classNames: ["composer-actions"],

  selectKitOptions: {
    icon: "share",
    filterable: false,
    showFullTitle: false
  },

  didReceiveAttrs() {
    this._super(...arguments);

    // if we change topic we want to change both snapshots
    if (
      this.get("composerModel.topic") &&
      (!_topicSnapshot ||
        this.get("composerModel.topic.id") !== _topicSnapshot.id)
    ) {
      _topicSnapshot = this.get("composerModel.topic");
      _postSnapshot = this.get("composerModel.post");
    }

    // if we hit reply on a different post we want to change postSnapshot
    if (
      this.get("composerModel.post") &&
      (!_postSnapshot || this.get("composerModel.post.id") !== _postSnapshot.id)
    ) {
      _postSnapshot = this.get("composerModel.post");
    }

    if (isEmpty(this.content)) {
      this.set("selectKit.isHidden", true);
    }
  },

  modifySelection() {
    return {};
  },

  content: computed(function() {
    let items = [];

    if (
      this.action !== CREATE_TOPIC &&
      this.action !== CREATE_SHARED_DRAFT &&
      _topicSnapshot
    ) {
      items.push({
        name: I18n.t("composer.composer_actions.reply_as_new_topic.label"),
        description: I18n.t(
          "composer.composer_actions.reply_as_new_topic.desc"
        ),
        icon: "plus",
        id: "reply_as_new_topic"
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
          postNumber: _postSnapshot.post_number,
          postUsername: _postSnapshot.username
        }),
        description: I18n.t("composer.composer_actions.reply_to_post.desc"),
        icon: "share",
        id: "reply_to_post"
      });
    }

    if (
      this.siteSettings.enable_personal_messages &&
      this.action !== PRIVATE_MESSAGE
    ) {
      items.push({
        name: I18n.t(
          "composer.composer_actions.reply_as_private_message.label"
        ),
        description: I18n.t(
          "composer.composer_actions.reply_as_private_message.desc"
        ),
        icon: "envelope",
        id: "reply_as_private_message"
      });
    }

    if (
      (this.action !== REPLY && _topicSnapshot) ||
      (this.action === REPLY &&
        _topicSnapshot &&
        this.replyOptions.userAvatar &&
        this.replyOptions.userLink &&
        this.replyOptions.topicLink)
    ) {
      items.push({
        name: I18n.t("composer.composer_actions.reply_to_topic.label"),
        description: I18n.t("composer.composer_actions.reply_to_topic.desc"),
        icon: "share",
        id: "reply_to_topic"
      });
    }

    // if answered post is a whisper, we can only answer with a whisper so no need for toggle
    if (
      this.canWhisper &&
      (!_postSnapshot ||
        (_postSnapshot &&
          _postSnapshot.post_type !== this.site.post_types.whisper))
    ) {
      items.push({
        name: I18n.t("composer.composer_actions.toggle_whisper.label"),
        description: I18n.t("composer.composer_actions.toggle_whisper.desc"),
        icon: "far-eye-slash",
        id: "toggle_whisper"
      });
    }

    let showCreateTopic = false;
    if (this.action === CREATE_SHARED_DRAFT) {
      showCreateTopic = true;
    }

    if (this.action === CREATE_TOPIC) {
      if (this.site.shared_drafts_category_id) {
        // Shared Drafts Choice
        items.push({
          name: I18n.t("composer.composer_actions.shared_draft.label"),
          description: I18n.t("composer.composer_actions.shared_draft.desc"),
          icon: "far-clipboard",
          id: "shared_draft"
        });
      }

      // Edge case: If personal messages are disabled, it is possible to have
      // no items which stil renders a button that pops up nothing. In this
      // case, add an option for what you're currently doing.
      if (items.length === 0) {
        showCreateTopic = true;
      }
    }

    if (showCreateTopic) {
      items.push({
        name: I18n.t("composer.composer_actions.create_topic.label"),
        description: I18n.t(
          "composer.composer_actions.reply_as_new_topic.desc"
        ),
        icon: "share",
        id: "create_topic"
      });
    }

    const showToggleTopicBump =
      this.get("currentUser.staff") ||
      this.get("currentUser.trust_level") === 4;

    if (this.action === REPLY && showToggleTopicBump) {
      items.push({
        name: I18n.t("composer.composer_actions.toggle_topic_bump.label"),
        description: I18n.t("composer.composer_actions.toggle_topic_bump.desc"),
        icon: "anchor",
        id: "toggle_topic_bump"
      });
    }

    return items;
  }),

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
    Draft.get("new_topic").then(response => {
      if (response.draft) {
        bootbox.confirm(
          I18n.t("composer.composer_actions.reply_as_new_topic.confirm"),
          result => {
            if (result) this._replyAsNewTopicSelect(options);
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
    options.usernames = usernames;
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
            "reply",
            "disableScopedCategory"
          ),
          this.composerModel
        );
      } else {
        // eslint-disable-next-line no-console
        console.error(`No method '${action}' found`);
      }
    }
  }
});
