import { iconHTML } from 'discourse-common/lib/icon-library';
import DropdownSelectBox from "select-box-kit/components/dropdown-select-box";
import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";

export default DropdownSelectBox.extend({
  headerText: "admin.flags.agree",
  headerIcon: "thumbs-o-up",
  classNames: ["agree-flag", "admin-agree-flag-dropdown"],
  adminTools: Ember.inject.service(),
  nameProperty: "label",

  @on("didReceiveAttrs")
  _setAdminAgreeDropdownOptions() {
    this.get('headerComponentOptions').setProperties({
      selectedName: `${I18n.t(this.get("headerText"))} ...`,
      icon: iconHTML("thumbs-o-up")
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

    if (post.user_deleted) {
      content.push({
        icon: "eye",
        id: "confirm-agree-restore",
        action: () => this.send("perform", "restore"),
        label:  I18n.t("admin.flags.agree_flag_restore_post"),
        description:  I18n.t("admin.flags.agree_flag_restore_post_title")
      });
    } else {
      if (!post.get("postHidden")) {
        content.push({
          icon: "eye-slash",
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
      description: I18n.t('admin.flags.agree_flag_title'),
      action: () => this.send("perform", "keep"),
      label:  I18n.t("admin.flags.agree_flag"),
    });

    if (canDeleteSpammer) {
      content.push({
        title:  I18n.t("admin.flags.delete_spammer_title"),
        icon: "exclamation-triangle",
        id: "delete-spammer",
        action: () => this.send("deleteSpammer"),
        label:  I18n.t("admin.flags.delete_spammer"),
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

    perform(action) {
      let flaggedPost = this.get("post");
      this.attrs.removeAfter(flaggedPost.agreeFlags(action));
    },
  }
});
