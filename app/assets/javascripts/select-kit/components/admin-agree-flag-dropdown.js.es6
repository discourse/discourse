import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import computed from "ember-addons/ember-computed-decorators";

export default DropdownSelectBox.extend({
  pluginApiIdentifiers: ["admin-agree-flag-dropdown"],
  classNames: ["agree-flag", "admin-agree-flag-dropdown"],
  adminTools: Ember.inject.service(),
  nameProperty: "label",
  allowInitialValueMutation: false,
  headerIcon: "thumbs-o-up",

  computeHeaderContent() {
    let content = this._super(...arguments);
    content.name = `${I18n.t("admin.flags.agree")}...`;
    return content;
  },

  @computed("adminTools", "post.user")
  spammerDetails(adminTools, user) {
    return adminTools.spammerDetails(user);
  },

  canDeleteSpammer: Ember.computed.and(
    "spammerDetails.canDelete",
    "post.flaggedForSpam"
  ),

  computeContent() {
    const content = [];
    const post = this.get("post");
    const canDeleteSpammer = this.get("canDeleteSpammer");

    if (post.user_deleted) {
      content.push({
        icon: "far-eye",
        id: "confirm-agree-restore",
        action: () => this.send("perform", "restore"),
        label: I18n.t("admin.flags.agree_flag_restore_post"),
        description: I18n.t("admin.flags.agree_flag_restore_post_title")
      });
    } else {
      if (!post.get("postHidden")) {
        content.push({
          icon: "far-eye-slash",
          action: () => this.send("perform", "hide"),
          id: "confirm-agree-hide",
          label: I18n.t("admin.flags.agree_flag_hide_post"),
          description: I18n.t("admin.flags.agree_flag_hide_post_title")
        });
      }
    }

    content.push({
      icon: "thumbs-o-up",
      id: "confirm-agree-keep",
      description: I18n.t("admin.flags.agree_flag_title"),
      action: () => this.send("perform", "keep"),
      label: I18n.t("admin.flags.agree_flag")
    });

    content.push({
      icon: "ban",
      id: "confirm-agree-suspend",
      description: I18n.t("admin.flags.agree_flag_suspend_title"),
      action: () => this.send("showSuspendModal"),
      label: I18n.t("admin.flags.agree_flag_suspend")
    });

    content.push({
      icon: "microphone-slash",
      id: "confirm-agree-silence",
      description: I18n.t("admin.flags.agree_flag_silence_title"),
      action: () => this.send("showSilenceModal"),
      label: I18n.t("admin.flags.agree_flag_silence")
    });

    if (canDeleteSpammer) {
      content.push({
        title: I18n.t("admin.flags.delete_spammer_title"),
        icon: "exclamation-triangle",
        id: "delete-spammer",
        action: () => this.send("deleteSpammer"),
        label: I18n.t("admin.flags.delete_spammer")
      });
    }

    return content;
  },

  mutateValue(value) {
    const computedContentItem = this.get("computedContent").findBy(
      "value",
      value
    );
    Ember.get(computedContentItem, "originalContent.action")();
  },

  actions: {
    deleteSpammer() {
      let spammerDetails = this.get("spammerDetails");
      this.attrs.removeAfter(spammerDetails.deleteUser());
    },

    showSuspendModal() {
      let post = this.get("post");
      let user = post.get("user");
      this.get("adminTools").showSuspendModal(user, {
        post,
        before: () => {
          return this.attrs.removeAfter(post.agreeFlags("suspended"));
        }
      });
    },

    showSilenceModal() {
      let post = this.get("post");
      let user = post.get("user");
      this.get("adminTools").showSilenceModal(user, {
        post,
        before: () => {
          return this.attrs.removeAfter(post.agreeFlags("silenced"));
        }
      });
    },

    perform(action) {
      let flaggedPost = this.get("post");
      this.attrs.removeAfter(flaggedPost.agreeFlags(action));
    }
  }
});
