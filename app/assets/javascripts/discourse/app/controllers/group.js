import I18n from "I18n";
import EmberObject, { action } from "@ember/object";
import Controller, { inject as controller } from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import { readOnly } from "@ember/object/computed";
import deprecated from "discourse-common/lib/deprecated";

const Tab = EmberObject.extend({
  init() {
    this._super(...arguments);

    this.setProperties({
      route: this.route || `group.${this.name}`,
      message: I18n.t(`groups.${this.i18nKey || this.name}`)
    });
  }
});

export default Controller.extend({
  application: controller(),
  counts: null,
  showing: "members",
  destroying: null,
  router: service(),
  currentPath: readOnly("router.currentRouteName"),

  @discourseComputed(
    "showMessages",
    "model.user_count",
    "model.request_count",
    "canManageGroup",
    "model.allow_membership_requests"
  )
  tabs(
    showMessages,
    userCount,
    requestCount,
    canManageGroup,
    allowMembershipRequests
  ) {
    const membersTab = Tab.create({
      name: "members",
      route: "group.index",
      icon: "users",
      i18nKey: "members.title",
      count: userCount
    });

    const defaultTabs = [membersTab, Tab.create({ name: "activity" })];

    if (canManageGroup && allowMembershipRequests) {
      defaultTabs.push(
        Tab.create({
          name: "requests",
          i18nKey: "requests.title",
          icon: "user-plus",
          count: requestCount
        })
      );
    }

    if (showMessages) {
      defaultTabs.push(
        Tab.create({
          name: "messages",
          i18nKey: "messages"
        })
      );
    }

    if (canManageGroup) {
      defaultTabs.push(
        Tab.create({
          name: "manage",
          i18nKey: "manage.title",
          icon: "wrench"
        })
      );
    }

    return defaultTabs;
  },

  @discourseComputed("model.is_group_user")
  showMessages(isGroupUser) {
    if (!this.siteSettings.enable_personal_messages) {
      return false;
    }

    return isGroupUser || (this.currentUser && this.currentUser.admin);
  },

  @discourseComputed("model.is_group_owner", "model.automatic")
  canEditGroup(isGroupOwner, automatic) {
    return !automatic && isGroupOwner;
  },

  @discourseComputed("model.displayName", "model.full_name")
  groupName(displayName, fullName) {
    return (fullName || displayName).capitalize();
  },

  @discourseComputed(
    "model.name",
    "model.flair_url",
    "model.flair_bg_color",
    "model.flair_color"
  )
  avatarFlairAttributes(groupName, flairURL, flairBgColor, flairColor) {
    return {
      primary_group_flair_url: flairURL,
      primary_group_flair_bg_color: flairBgColor,
      primary_group_flair_color: flairColor,
      primary_group_name: groupName
    };
  },

  @discourseComputed("model.messageable")
  displayGroupMessageButton(messageable) {
    return this.currentUser && messageable;
  },

  @discourseComputed("model", "model.automatic")
  canManageGroup(model, automatic) {
    return (
      this.currentUser &&
      (this.currentUser.canManageGroup(model) ||
        (this.currentUser.admin && automatic))
    );
  },

  @action
  messageGroup() {
    this.send("createNewMessageViaParams", this.get("model.name"));
  },

  @action
  destroyGroup() {
    this.set("destroying", true);

    bootbox.confirm(
      I18n.t("admin.groups.delete_confirm"),
      I18n.t("no_value"),
      I18n.t("yes_value"),
      confirmed => {
        if (confirmed) {
          this.model
            .destroy()
            .then(() => this.transitionToRoute("groups.index"))
            .catch(error => {
              // eslint-disable-next-line no-console
              console.error(error);
              bootbox.alert(I18n.t("admin.groups.delete_failed"));
            })
            .finally(() => this.set("destroying", false));
        } else {
          this.set("destroying", false);
        }
      }
    );
  },

  actions: {
    destroy() {
      deprecated("Use `destroyGroup` action instead of `destroy`.", {
        since: "2.5.0",
        dropFrom: "2.6.0"
      });

      this.destroyGroup();
    }
  }
});
