import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import computed from "ember-addons/ember-computed-decorators";
import {
  PRIVATE_MESSAGE,
  CREATE_TOPIC,
  CREATE_SHARED_DRAFT,
  REPLY,
  EDIT,
  NEW_PRIVATE_MESSAGE_KEY
} from "discourse/models/composer";

// Component can get destroyed and lose state
let _topicSnapshot = null;
let _postSnapshot = null;

export function _clearSnapshots() {
  _topicSnapshot = null;
  _postSnapshot = null;
}

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["composer-actions"],
  classNames: "composer-actions",
  fullWidthOnMobile: true,
  autofilterable: false,
  filterable: false,
  allowInitialValueMutation: false,
  allowAutoSelectFirst: false,
  showFullTitle: false,
  isHidden: Ember.computed.empty("content"),

  didReceiveAttrs() {
    this._super(...arguments);

    // if we change topic we want to change both snapshots
    if (
      this.get("composerModel.topic") &&
      (!_topicSnapshot ||
        this.get("composerModel.topic.id") !== _topicSnapshot.get("id"))
    ) {
      _topicSnapshot = this.get("composerModel.topic");
      _postSnapshot = this.get("composerModel.post");
    }

    // if we hit reply on a different post we want to change postSnapshot
    if (
      this.get("composerModel.post") &&
      (!_postSnapshot ||
        this.get("composerModel.post.id") !== _postSnapshot.get("id"))
    ) {
      _postSnapshot = this.get("composerModel.post");
    }
  },

  computeHeaderContent() {
    let content = this._super(...arguments);

    switch (this.get("action")) {
      case PRIVATE_MESSAGE:
      case CREATE_TOPIC:
      case REPLY:
        content.icon = "mail-forward";
        content.title = I18n.t("composer.composer_actions.reply");
        break;
      case EDIT:
        content.icon = "pencil-alt";
        content.title = I18n.t("composer.composer_actions.edit");
        break;
      case CREATE_SHARED_DRAFT:
        content.icon = "clipboard";
        content.title = I18n.t("composer.composer_actions.draft");
        break;
    }

    return content;
  },

  @computed("options", "canWhisper", "action")
  content(options, canWhisper, action) {
    let items = [];

    if (
      action !== CREATE_TOPIC &&
      action !== CREATE_SHARED_DRAFT &&
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
      (action !== REPLY && _postSnapshot) ||
      (action === REPLY &&
        _postSnapshot &&
        !(options.userAvatar && options.userLink))
    ) {
      items.push({
        name: I18n.t("composer.composer_actions.reply_to_post.label", {
          postNumber: _postSnapshot.get("post_number"),
          postUsername: _postSnapshot.get("username")
        }),
        description: I18n.t("composer.composer_actions.reply_to_post.desc"),
        icon: "mail-forward",
        id: "reply_to_post"
      });
    }

    if (
      this.siteSettings.enable_personal_messages &&
      action !== PRIVATE_MESSAGE
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
      (action !== REPLY && _topicSnapshot) ||
      (action === REPLY &&
        _topicSnapshot &&
        (options.userAvatar && options.userLink && options.topicLink))
    ) {
      items.push({
        name: I18n.t("composer.composer_actions.reply_to_topic.label"),
        description: I18n.t("composer.composer_actions.reply_to_topic.desc"),
        icon: "mail-forward",
        id: "reply_to_topic"
      });
    }

    // if answered post is a whisper, we can only answer with a whisper so no need for toggle
    if (
      canWhisper &&
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
    if (action === CREATE_SHARED_DRAFT) {
      showCreateTopic = true;
    }

    if (action === CREATE_TOPIC) {
      if (this.site.shared_drafts_category_id) {
        // Shared Drafts Choice
        items.push({
          name: I18n.t("composer.composer_actions.shared_draft.label"),
          description: I18n.t("composer.composer_actions.shared_draft.desc"),
          icon: "clipboard",
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
        icon: "mail-forward",
        id: "create_topic"
      });
    }

    const currentUser = Discourse.User.current();
    const showToggleTopicBump =
      currentUser &&
      (currentUser.get("staff") || currentUser.trust_level === 4);

    if (action === REPLY && showToggleTopicBump) {
      items.push({
        name: I18n.t("composer.composer_actions.toggle_topic_bump.label"),
        description: I18n.t("composer.composer_actions.toggle_topic_bump.desc"),
        icon: "anchor",
        id: "toggle_topic_bump"
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

  replyToTopicSelected(options) {
    options.action = REPLY;
    options.topic = _topicSnapshot;
    this._openComposer(options);
  },

  replyToPostSelected(options) {
    options.action = REPLY;
    options.post = _postSnapshot;
    this._openComposer(options);
  },

  replyAsNewTopicSelected(options) {
    options.action = CREATE_TOPIC;
    options.categoryId = this.get("composerModel.topic.category.id");
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
    options.draftKey = NEW_PRIVATE_MESSAGE_KEY;

    this._replyFromExisting(options, _postSnapshot, _topicSnapshot);
  },

  _switchCreate(options, action) {
    options.action = action;
    options.categoryId = this.get("composerModel.categoryId");
    options.topicTitle = this.get("composerModel.title");
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
    onSelect(value) {
      let action = `${Ember.String.camelize(value)}Selected`;
      if (this[action]) {
        let model = this.get("composerModel");
        this[action](
          model.getProperties("draftKey", "draftSequence", "reply"),
          model
        );
      } else {
        // eslint-disable-next-line no-console
        console.error(`No method '${action}' found`);
      }
    }
  }
});
