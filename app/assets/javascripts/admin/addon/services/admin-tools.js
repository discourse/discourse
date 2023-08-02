import AdminUser from "admin/models/admin-user";
import I18n from "I18n";
import { Promise } from "rsvp";
import Service, { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { getOwner } from "discourse-common/lib/get-owner";
import { htmlSafe } from "@ember/template";
import { action } from "@ember/object";
import PenalizeUserModal from "admin/components/modal/penalize-user";

// A service that can act as a bridge between the front end Discourse application
// and the admin application. Use this if you need front end code to access admin
// modules. Inject it optionally, and if it exists go to town!
export default class AdminToolsService extends Service {
  @service dialog;
  @service modal;

  showActionLogs(target, filters) {
    const controller = getOwner(target).lookup(
      "controller:adminLogs.staffActionLogs"
    );
    target.transitionToRoute("adminLogs.staffActionLogs").then(() => {
      controller.changeFilters(filters);
    });
  }

  checkSpammer(userId) {
    return AdminUser.find(userId).then((au) => this.spammerDetails(au));
  }

  deleteUser(id, formData) {
    return AdminUser.find(id).then((user) => user.destroy(formData));
  }

  spammerDetails(adminUser) {
    return {
      deleteUser: () => this._deleteSpammer(adminUser),
      canDelete:
        adminUser.get("can_be_deleted") &&
        adminUser.get("can_delete_all_posts"),
    };
  }

  @action
  async showControlModal(type, user, opts) {
    opts = opts || {};

    const userLookup = user.adminUserView
      ? Promise.resolve(user)
      : AdminUser.find(user.get("id"));
    const loadedUser = await userLookup;
    this.modal.show(PenalizeUserModal, {
      model: {
        penaltyType: type,
        postId: opts.postId,
        postEdit: opts.postEdit,
        user: loadedUser,
        before: opts.before,
        successCallback: opts.successCallback,
      },
    });
  }

  showSilenceModal(user, opts) {
    this.showControlModal("silence", user, opts);
  }

  showSuspendModal(user, opts) {
    this.showControlModal("suspend", user, opts);
  }

  _deleteSpammer(adminUser) {
    // Try loading the email if the site supports it
    let tryEmail = this.siteSettings.moderators_view_emails
      ? adminUser.checkEmail()
      : Promise.resolve();

    return tryEmail.then(() => {
      let message = htmlSafe(
        I18n.messageFormat("flagging.delete_confirm_MF", {
          POSTS: adminUser.get("post_count"),
          TOPICS: adminUser.get("topic_count"),
          email:
            adminUser.get("email") || I18n.t("flagging.hidden_email_address"),
          ip_address:
            adminUser.get("ip_address") ||
            I18n.t("flagging.ip_address_missing"),
        })
      );

      let userId = adminUser.get("id");

      return new Promise((resolve, reject) => {
        this.dialog.deleteConfirm({
          message,
          class: "flagging-delete-spammer",
          confirmButtonLabel: "flagging.yes_delete_spammer",
          confirmButtonIcon: "exclamation-triangle",
          didConfirm: () => {
            return ajax(`/admin/users/${userId}.json`, {
              type: "DELETE",
              data: {
                delete_posts: true,
                block_email: true,
                block_urls: true,
                block_ip: true,
                delete_as_spammer: true,
                context: window.location.pathname,
              },
            })
              .then((result) => {
                if (result.deleted) {
                  resolve();
                } else {
                  throw new Error("failed to delete");
                }
              })
              .catch(() => {
                this.dialog.alert(I18n.t("admin.user.delete_failed"));
                reject();
              });
          },
        });
      });
    });
  }
}
