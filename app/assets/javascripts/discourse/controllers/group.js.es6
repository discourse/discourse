import EmberObject from "@ember/object";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import { readOnly } from "@ember/object/computed";

const Tab = EmberObject.extend({
  init() {
    this._super(...arguments);
    let name = this.name;
    this.set("route", this.route || `group.` + name);
    this.set("message", I18n.t(`groups.${this.i18nKey || name}`));
  }
});

export default Controller.extend({
  application: inject(),
  counts: null,
  showing: "members",
  destroying: null,
  router: service(),
  currentPath: readOnly("router._router.currentPath"),

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
      i18nKey: "members.title"
    });

    membersTab.set("count", userCount);

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

  actions: {
    messageGroup() {
      this.send("createNewMessageViaParams", this.get("model.name"));
    },

    destroy() {
      const group = this.model;
      this.set("destroying", true);

      bootbox.confirm(
        I18n.t("admin.groups.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        confirmed => {
          if (confirmed) {
            group
              .destroy()
              .then(() => {
                this.transitionToRoute("groups.index");
              })
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
    }
  }
});
