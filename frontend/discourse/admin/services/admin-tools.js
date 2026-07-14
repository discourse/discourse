import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { Promise } from "rsvp";
import DeleteUserPostsProgressModal from "discourse/admin/components/modal/delete-user-posts-progress";
import PenalizeUserModal from "discourse/admin/components/modal/penalize-user";
import AdminUser from "discourse/admin/models/admin-user";
import { ajax } from "discourse/lib/ajax";
import I18n, { i18n } from "discourse-i18n";

// A service that can act as a bridge between the front end Discourse application
// and the admin application. Use this if you need front end code to access admin
// modules. Inject it optionally, and if it exists go to town!
export default class AdminToolsService extends Service {
  @service dialog;
  @service modal;
  @service router;

  showActionLogs(target, filters) {
    this.router.transitionTo("adminLogs.staffActionLogs", {
      queryParams: { filters, force_refresh: true },
    });
  }

  checkSpammer(userId) {
    return AdminUser.find(userId).then((au) => this.spammerDetails(au));
  }

  deleteUser(id, formData) {
    return AdminUser.find(id).then((user) => user.destroy(formData));
  }

  get deleteUserOptions() {
    return [
      {
        id: "delete_dont_block",
        label: i18n("admin.user.delete_dont_block"),
        description: i18n("admin.user.delete_dont_block_description"),
        icon: "trash-can",
      },
      {
        id: "delete_and_block_email",
        label: i18n("admin.user.delete_and_block_email"),
        description: i18n("admin.user.delete_and_block_email_description"),
        icon: "envelope",
        blockFlags: { block_email: true },
      },
      {
        id: "delete_and_block",
        label: i18n("admin.user.delete_and_block"),
        description: i18n("admin.user.delete_and_block_description"),
        icon: "ban",
        blockFlags: { block_email: true, block_urls: true, block_ip: true },
      },
    ];
  }

  showDeleteUserModal(
    userId,
    optionId,
    { deletePosts = false, onDeleted } = {}
  ) {
    const option = this.deleteUserOptions.find((o) => o.id === optionId);
    const blockFlags = option?.blockFlags ?? {};
    const block = Object.keys(blockFlags).length > 0;

    this.dialog.deleteConfirm({
      title: i18n("admin.user.delete_confirm_title"),
      message: i18n("admin.user.delete_confirm"),
      class: `delete-user-modal ${
        block ? "delete-and-block" : "delete-dont-block"
      }`,
      confirmButtonLabel: `admin.user.${optionId}`,
      confirmButtonIcon: block ? "triangle-exclamation" : "trash-can",
      didConfirm: async () => {
        this.dialog.notice(i18n("admin.user.deleting_user"));

        const formData = { context: document.location.pathname, ...blockFlags };
        if (deletePosts) {
          formData.delete_posts = true;
        }

        try {
          const data = await this.deleteUser(userId, formData);
          if (data?.deleted) {
            onDeleted?.();
          } else {
            this.dialog.alert(i18n("admin.user.delete_failed"));
          }
        } catch {
          this.dialog.alert(i18n("admin.user.delete_failed"));
        }
      },
    });
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
    const loadedUser = user.adminUserView
      ? user
      : await AdminUser.find(user.get("id"));
    const originalSuccessCallback = opts.successCallback;
    return this.modal.show(PenalizeUserModal, {
      model: {
        penaltyType: type,
        postId: opts.postId,
        postEdit: opts.postEdit,
        reviewableId: opts.reviewableId,
        user: loadedUser,
        before: opts.before,
        successCallback: async (result) => {
          if (originalSuccessCallback) {
            await originalSuccessCallback(result);
          }

          if (result?.shouldDeleteAllPosts) {
            return this.deletePostsDecider(loadedUser);
          }
        },
      },
    });
  }

  showSilenceModal(user, opts) {
    return this.showControlModal("silence", user, opts);
  }

  showSuspendModal(user, opts) {
    return this.showControlModal("suspend", user, opts);
  }

  _deleteSpammer(adminUser) {
    // Try loading the email if the site supports it
    let tryEmail = this.siteSettings.moderators_view_emails
      ? adminUser.checkEmail()
      : Promise.resolve();

    return tryEmail.then(() => {
      let message = trustHTML(
        I18n.messageFormat("flagging.delete_confirm_MF", {
          POSTS: adminUser.get("post_count"),
          TOPICS: adminUser.get("topic_count"),
          email:
            adminUser.get("email") || i18n("flagging.hidden_email_address"),
          ip_address:
            adminUser.get("ip_address") || i18n("flagging.ip_address_missing"),
        })
      );

      let userId = adminUser.get("id");

      return new Promise((resolve, reject) => {
        this.dialog.deleteConfirm({
          message,
          class: "flagging-delete-spammer",
          confirmButtonLabel: "flagging.yes_delete_spammer",
          confirmButtonIcon: "triangle-exclamation",
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
                this.dialog.alert(i18n("admin.user.delete_failed"));
                reject();
              });
          },
        });
      });
    });
  }

  async deletePostsDecider(user) {
    const response = await ajax(
      `/admin/users/${user.id}/delete_posts_decider`,
      {
        type: "POST",
      }
    );

    if (response.job_enqueued) {
      this.dialog.alert(
        i18n("admin.user.delete_posts.all_enqueued", {
          username: user.username,
        })
      );
      this.modal.close();
      return;
    }

    this.modal.show(DeleteUserPostsProgressModal, {
      model: {
        user,
        updateUserPostCount(count) {
          user.set("post_count", count);
        },
      },
    });
  }
}
