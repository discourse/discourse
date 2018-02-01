import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { default as Composer, REPLY, EDIT } from "discourse/models/composer";

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

  computeHeaderContent() {
    let content = this.baseHeaderComputedContent();

    switch (this.get("action")) {
      case REPLY:
        content.icon = "mail-forward";
        break;
      case EDIT:
        content.icon = "pencil";
        break;
    };

    return content;
  },

  @computed("options", "canWhisper", "composerModel.post.username")
  content(options, canWhisper, postUsername) {
    let items = [
      {
        name: I18n.t("composer.composer_actions.reply_as_new_topic.label"),
        description: I18n.t("composer.composer_actions.reply_as_new_topic.desc"),
        icon: "plus",
        id: "reply_as_new_topic"
      }
    ];

    if (postUsername && postUsername !== this.currentUser.get("username")) {
      items.push({
        name: I18n.t("composer.composer_actions.reply_as_private_message.label"),
        description: I18n.t("composer.composer_actions.reply_as_private_message.desc"),
        icon: "envelope",
        id: "reply_as_private_message"
      });
    }

    if (Ember.get(options, "postLink")) {
      items.push({
        name: I18n.t("composer.composer_actions.reply_to_topic.label"),
        description: I18n.t("composer.composer_actions.reply_to_topic.desc"),
        icon: "mail-forward",
        id: "reply_to_topic"
      });
    }

    if (canWhisper) {
      items.push({
        name: I18n.t("composer.composer_actions.toggle_whisper.label"),
        description: I18n.t("composer.composer_actions.toggle_whisper.desc"),
        icon: "eye-slash",
        id: "toggle_whisper"
      });
    }

    return items;
  },

  _replyFromExisting(options) {
    const topicTitle = this.get("composerModel.topic.title");
    let url = this.get("composerModel.post.url") || this.get("composerModel.topic.url");

    this.get("composerController").open(options).then(() => {
      url = `${location.protocol}//${location.host}${url}`;
      const link = `[${Handlebars.escapeExpression(topicTitle)}](${url})`;
      this.get("composerController").get("model").prependText(`${I18n.t("post.continue_discussion", { postLink: link })}`, {new_line: true});
    });
  },

  actions: {
    onSelect(value) {
      switch(value) {
        case "toggle_whisper":
          this.set("composerModel.whisper", !this.get("composerModel.whisper"));
          break;

        case "reply_to_topic":
          this.set("composerModel.post", null);
          this.get("composerController").save();
          break;

        case "reply_as_new_topic":
          const replyAsNewTopicOpts = {
            action: Composer.CREATE_TOPIC,
            draftKey: Composer.REPLY_AS_NEW_TOPIC_KEY,
            categoryId: this.get("composerModel.topic.category.id")
          };
          this._replyFromExisting(replyAsNewTopicOpts);
          break;

        case "reply_as_private_message":
          const replyAsPrivateMsgOpts = {
            action: Composer.PRIVATE_MESSAGE,
            archetypeId: "private_message",
            draftKey: Composer.REPLY_AS_NEW_PRIVATE_MESSAGE_KEY,
            usernames: this.get("composerModel.post.username")
          };
          this._replyFromExisting(replyAsPrivateMsgOpts);
          break;
      }
    }
  }
});
