import { iconHTML } from 'discourse-common/lib/icon-library';
import DropdownSelectBox from "select-box-kit/components/dropdown-select-box";
import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";

export default DropdownSelectBox.extend({
  headerText: "admin.flags.delete",
  classNames: ["delete-flag", "admin-delete-flag-dropdown"],
  adminTools: Ember.inject.service(),
  nameProperty: "label",

  @on("didReceiveAttrs")
  _setAdminDeleteDropdownOptions() {
    this.get('headerComponentOptions').setProperties({
      selectedName: `${I18n.t(this.get("headerText"))} ...`,
      icon: iconHTML("trash-o")
    });
  },

  @computed("adminTools", "post.user")
  spammerDetails(adminTools, user) {
    return adminTools.spammerDetails(user);
  },

  canDeleteSpammer: Ember.computed.and("spammerDetails.canDelete", "post.flaggedForSpam"),

  @computed("post", "canDeleteSpammer")
  content(post, canDeleteSpammer) {
    const content = [];

    content.push({
      icon: "external-link",
      id: "delete-defer",
      action: () => this.send("deletePostDeferFlag"),
      label: I18n.t("admin.flags.delete_post_defer_flag"),
      description:  I18n.t("admin.flags.delete_post_defer_flag_title"),
    });

    content.push({
      icon: "thumbs-o-up",
      id: "delete-agree",
      action: () => this.send("deletePostAgreeFlag"),
      label: I18n.t("admin.flags.delete_post_agree_flag"),
      description:  I18n.t("admin.flags.delete_post_agree_flag_title"),
    });

    if (canDeleteSpammer) {
      content.push({
        title:  I18n.t("admin.flags.delete_post_agree_flag_title"),
        icon: "exclamation-triangle",
        id: "delete-spammer",
        action: () => this.send("deleteSpammer"),
        label: I18n.t("admin.flags.delete_spammer")
      });
    }

    return content;
  },

  selectValueFunction(value) {
    Ember.get(this._contentForValue(value), "action")();
  },

  actions: {
    deleteSpammer() {
      let spammerDetails = this.get("spammerDetails");
      this.attrs.removeAfter(spammerDetails.deleteUser());
    },

    deletePostDeferFlag() {
      let flaggedPost = this.get('post');
      this.attrs.removeAfter(flaggedPost.deferFlags(true));
    },

    deletePostAgreeFlag() {
      let flaggedPost = this.get('post');
      this.attrs.removeAfter(flaggedPost.agreeFlags('delete'));
    }
  }
});
