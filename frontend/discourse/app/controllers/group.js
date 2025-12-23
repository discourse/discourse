import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action, computed } from "@ember/object";
import { service } from "@ember/service";
import GroupDeleteDialog from "discourse/components/dialog-messages/group-delete";
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

  @computed(
    "showMessages",
    "model.user_count",
    "model.request_count",
    "canManageGroup",
    "model.allow_membership_requests"
  )
  get tabs() {
    const membersTab = Tab.create({
      name: "members",
      route: "group.index",
      icon: "users",
      i18nKey: "members.title",
      count: this.model?.user_count,
    });

    const defaultTabs = [
      membersTab,
      Tab.create({ name: "activity", icon: "bars-staggered" }),
    ];

    if (this.canManageGroup && this.model?.allow_membership_requests) {
      defaultTabs.push(
        Tab.create({
          name: "requests",
          i18nKey: "requests.title",
          icon: "user-plus",
          count: this.model?.request_count,
        })
      );
    }

    if (this.showMessages) {
      defaultTabs.push(
        Tab.create({
          name: "messages",
          i18nKey: "messages",
          icon: "envelope",
        })
      );
    }

    if (this.canManageGroup) {
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
        icon: "id-card",
      })
    );

    return defaultTabs;
  }

  @computed(
    "model.has_messages",
    "model.is_group_user",
    "currentUser.can_send_private_messages"
  )
  get showMessages() {
    if (!this.currentUser?.can_send_private_messages) {
      return false;
    }

    if (!this.model?.has_messages) {
      return false;
    }

    return (
      this.model?.is_group_user || (this.currentUser && this.currentUser.admin)
    );
  }

  @computed("model.messageable")
  get displayGroupMessageButton() {
    return this.currentUser && this.model?.messageable;
  }

  @computed("model", "model.automatic")
  get canManageGroup() {
    return this.currentUser?.canManageGroup(this.model);
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
