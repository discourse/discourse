import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import computed from "ember-addons/ember-computed-decorators";
const { get } = Ember;

export default DropdownSelectBox.extend({
  classNames: ["delete-flag", "admin-delete-flag-dropdown"],
  adminTools: Ember.inject.service(),
  nameProperty: "label",
  headerIcon: "trash-o",

  computeHeaderContent() {
    let content = this._super(...arguments);
    content.name = `${I18n.t("admin.flags.delete")}...`;
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
    const canDeleteSpammer = this.get("canDeleteSpammer");

    content.push({
      icon: "external-link",
      id: "delete-defer",
      action: () => this.send("deletePostDeferFlag"),
      label: I18n.t("admin.flags.delete_post_defer_flag"),
      description: I18n.t("admin.flags.delete_post_defer_flag_title")
    });

    content.push({
      icon: "thumbs-o-up",
      id: "delete-agree",
      action: () => this.send("deletePostAgreeFlag"),
      label: I18n.t("admin.flags.delete_post_agree_flag"),
      description: I18n.t("admin.flags.delete_post_agree_flag_title")
    });

    if (canDeleteSpammer) {
      content.push({
        title: I18n.t("admin.flags.delete_post_agree_flag_title"),
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
    get(computedContentItem, "originalContent.action")();
  },

  actions: {
    deleteSpammer() {
      let spammerDetails = this.get("spammerDetails");
      this.attrs.removeAfter(spammerDetails.deleteUser());
    },

    deletePostDeferFlag() {
      let flaggedPost = this.get("post");
      this.attrs.removeAfter(flaggedPost.deferFlags(true));
    },

    deletePostAgreeFlag() {
      let flaggedPost = this.get("post");
      this.attrs.removeAfter(flaggedPost.agreeFlags("delete"));
    }
  }
});
