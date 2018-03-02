import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import computed from "ember-addons/ember-computed-decorators";
import { default as Composer, PRIVATE_MESSAGE, CREATE_TOPIC, REPLY, EDIT } from "discourse/models/composer";

// Component can get destroyed and lose state
let _topicSnapshot = null;
let _postSnapshot = null;

export function _clearSnapshots() {
  _topicSnapshot = null;
  _postSnapshot = null;
}

export default DropdownSelectBoxComponent.extend({
  composerController: Ember.inject.controller("composer"),
  pluginApiIdentifiers: ["composer-actions"],
  classNames: "composer-actions",
  fullWidthOnMobile: true,
  autofilterable: false,
  filterable: false,
  allowInitialValueMutation: false,
  allowAutoSelectFirst: false,
  showFullTitle: false,

  didReceiveAttrs() {
    this._super();

    // if we change topic we want to change both snapshots
    if (this.get("composerModel.topic") && (!_topicSnapshot || this.get("composerModel.topic.id") !== _topicSnapshot.get("id"))) {
      _topicSnapshot = this.get("composerModel.topic");
      _postSnapshot = this.get("composerModel.post");
    }

    // if we hit reply on a different post we want to change postSnapshot
    if (this.get("composerModel.post") && (!_postSnapshot || this.get("composerModel.post.id") !== _postSnapshot.get("id"))) {
      _postSnapshot = this.get("composerModel.post");
    }
  },

  computeHeaderContent() {
    let content = this.baseHeaderComputedContent();

    switch (this.get("action")) {
      case PRIVATE_MESSAGE:
      case CREATE_TOPIC:
      case REPLY:
        content.icon = "mail-forward";
        break;
      case EDIT:
        content.icon = "pencil";
        break;
    };

    return content;
  },

  @computed("options", "canWhisper", "action")
  content(options, canWhisper, action) {
    let items = [];

    if (action !== CREATE_TOPIC) {
      items.push({
        name: I18n.t("composer.composer_actions.reply_as_new_topic.label"),
        description: I18n.t("composer.composer_actions.reply_as_new_topic.desc"),
        icon: "plus",
        id: "reply_as_new_topic"
      });
    }

    if ((action !== REPLY && _postSnapshot) || (action === REPLY && _postSnapshot && !(options.userAvatar && options.userLink))) {
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

    if (this.siteSettings.enable_personal_messages && action !== PRIVATE_MESSAGE) {
      items.push({
        name: I18n.t("composer.composer_actions.reply_as_private_message.label"),
        description: I18n.t("composer.composer_actions.reply_as_private_message.desc"),
        icon: "envelope",
        id: "reply_as_private_message"
      });
    }

    if ((action !== REPLY && _topicSnapshot) || (action === REPLY && _topicSnapshot && (options.userAvatar && options.userLink && options.topicLink))) {
      items.push({
        name: I18n.t("composer.composer_actions.reply_to_topic.label"),
        description: I18n.t("composer.composer_actions.reply_to_topic.desc"),
        icon: "mail-forward",
        id: "reply_to_topic"
      });
    }

    // if answered post is a whisper, we can only answer with a whisper so no need for toggle
    if (canWhisper && (!_postSnapshot || _postSnapshot && _postSnapshot.post_type !== this.site.post_types.whisper)) {
      items.push({
        name: I18n.t("composer.composer_actions.toggle_whisper.label"),
        description: I18n.t("composer.composer_actions.toggle_whisper.desc"),
        icon: "eye-slash",
        id: "toggle_whisper"
      });
    }

    // Edge case: If personal messages are disabled, it is possible to have
    // no items which stil renders a button that pops up nothing. In this
    // case, add an option for what you're currently doing.
    if (action === CREATE_TOPIC && items.length === 0) {
      items.push({
        name: I18n.t("composer.composer_actions.create_topic.label"),
        description: I18n.t("composer.composer_actions.reply_as_new_topic.desc"),
        icon: "mail-forward",
        id: "create_topic"
      });
    }
    return items;
  },

  _replyFromExisting(options, post, topic) {
    const reply = this.get("composerModel.reply");

    let url;
    if (post) url = post.get("url");
    if (!post && topic) url = topic.get("url");

    let topicTitle;
    if (topic) topicTitle = topic.get("title");

    this.get("composerController").close();
    this.get("composerController").open(options).then(() => {
      if (!url || ! topicTitle) return;

      url = `${location.protocol}//${location.host}${url}`;
      const link = `[${Handlebars.escapeExpression(topicTitle)}](${url})`;
      const continueDiscussion = I18n.t("post.continue_discussion", { postLink: link });

      if (!reply.includes(continueDiscussion)) {
        this.get("composerController")
            .get("model")
            .prependText(continueDiscussion, {new_line: true});
      }
    });
  },

  actions: {
    onSelect(value) {
      let options = {
        draftKey: this.get("composerModel.draftKey"),
        draftSequence: this.get("composerModel.draftSequence"),
        reply: this.get("composerModel.reply")
      };

      switch(value) {
        case "toggle_whisper":
          this.set("composerModel.whisper", !this.get("composerModel.whisper"));
          break;

        case "reply_to_post":
          options.action = Composer.REPLY;
          options.post = _postSnapshot;

          this.get("composerController").close();
          this.get("composerController").open(options);
          break;

        case "reply_to_topic":
          options.action = Composer.REPLY;
          options.topic = _topicSnapshot;

          this.get("composerController").close();
          this.get("composerController").open(options);
          break;

        case "reply_as_new_topic":
          options.action = Composer.CREATE_TOPIC;
          options.categoryId = this.get("composerModel.topic.category.id");

          this._replyFromExisting(options, _postSnapshot, _topicSnapshot);
          break;

        case "reply_as_private_message":
          let usernames;

          if (_postSnapshot && !_postSnapshot.get("yours")) {
            const postUsername = _postSnapshot.get("username");
            if (postUsername) {
              usernames = postUsername;
            }
          }

          options.action = Composer.PRIVATE_MESSAGE;
          options.usernames = usernames;
          options.archetypeId = "private_message";
          options.draftKey = Composer.NEW_PRIVATE_MESSAGE_KEY;

          this._replyFromExisting(options, _postSnapshot, _topicSnapshot);
          break;
      }
    }
  }
});
