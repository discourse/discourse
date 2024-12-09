import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import GroupDeleteDialog from "discourse/components/dialog-messages/group-delete";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

class Tab extends EmberObject {
  init() {
    super.init(...arguments);

    this.setProperties({
      route: this.route || `group.${this.name}`,
      message: i18n(`groups.${this.i18nKey || this.name}`),
    });
  }
}

export default class GroupController extends Controller {
  @service dialog;
  @service currentUser;
  @service router;
  @service composer;
  @controller application;

  counts = null;
  showing = "members";
  destroying = null;
  showTooltip = false;

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
      count: userCount,
    });

    const defaultTabs = [membersTab, Tab.create({ name: "activity" })];

    if (canManageGroup && allowMembershipRequests) {
      defaultTabs.push(
        Tab.create({
          name: "requests",
          i18nKey: "requests.title",
          icon: "user-plus",
          count: requestCount,
        })
      );
    }

    if (showMessages) {
      defaultTabs.push(
        Tab.create({
          name: "messages",
          i18nKey: "messages",
        })
      );
    }

    if (canManageGroup) {
      defaultTabs.push(
        Tab.create({
          name: "manage",
          i18nKey: "manage.title",
          icon: "wrench",
        })
      );
    }

    defaultTabs.push(
      Tab.create({
        name: "permissions",
        i18nKey: "permissions.title",
      })
    );

    return defaultTabs;
  }

  @discourseComputed(
    "model.has_messages",
    "model.is_group_user",
    "currentUser.can_send_private_messages"
  )
  showMessages(hasMessages, isGroupUser) {
    if (!this.currentUser?.can_send_private_messages) {
      return false;
    }

    if (!hasMessages) {
      return false;
    }

    return isGroupUser || (this.currentUser && this.currentUser.admin);
  }

  @discourseComputed("model.messageable")
  displayGroupMessageButton(messageable) {
    return this.currentUser && messageable;
  }

  @discourseComputed("model", "model.automatic")
  canManageGroup(model) {
    return this.currentUser?.canManageGroup(model);
  }

  @action
  messageGroup() {
    this.composer.openNewMessage({
      recipients: this.get("model.name"),
      hasGroups: true,
    });
  }

  @action
  destroyGroup() {
    this.set("destroying", true);

    const model = this.model;

    this.dialog.deleteConfirm({
      title: i18n("admin.groups.delete_confirm", { group: model.name }),
      bodyComponent: GroupDeleteDialog,
      bodyComponentModel: model,
      didConfirm: () => {
        model
          .destroy()
          .catch((error) => {
            // eslint-disable-next-line no-console
            console.error(error);
            this.dialog.alert(i18n("admin.groups.delete_failed"));
          })
          .then(() => {
            this.router.transitionTo("groups.index");
          })
          .finally(() => {
            this.set("destroying", false);
          });
      },
      didCancel: () => this.set("destroying", false),
    });
  }

  @action
  toggleDeleteTooltip() {
    this.toggleProperty("showTooltip");
  }
}
