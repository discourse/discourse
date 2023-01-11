import Component from "@ember/component";
import I18n from "I18n";
import cookie from "discourse/lib/cookie";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  classNames: ["group-membership-button"],
  dialog: service(),

  @discourseComputed("model.public_admission", "userIsGroupUser")
  canJoinGroup(publicAdmission, userIsGroupUser) {
    return publicAdmission && !userIsGroupUser;
  },

  @discourseComputed("model.public_exit", "userIsGroupUser")
  canLeaveGroup(publicExit, userIsGroupUser) {
    return publicExit && userIsGroupUser;
  },

  @discourseComputed("model.allow_membership_requests", "userIsGroupUser")
  canRequestMembership(allowMembershipRequests, userIsGroupUser) {
    return allowMembershipRequests && !userIsGroupUser;
  },

  @discourseComputed("model.is_group_user")
  userIsGroupUser(isGroupUser) {
    return !!isGroupUser;
  },

  _showLoginModal() {
    this.showLogin();
    cookie("destination_url", window.location.href);
  },

  removeFromGroup() {
    const model = this.model;
    model
      .leave()
      .then(() => {
        model.set("is_group_user", false);
        this.appEvents.trigger("group:leave", model);
      })
      .catch(popupAjaxError)
      .finally(() => this.set("updatingMembership", false));
  },

  actions: {
    joinGroup() {
      if (this.currentUser) {
        this.set("updatingMembership", true);
        const group = this.model;

        group
          .join()
          .then(() => {
            group.set("is_group_user", true);
            this.appEvents.trigger("group:join", group);
          })
          .catch(popupAjaxError)
          .finally(() => {
            this.set("updatingMembership", false);
          });
      } else {
        this._showLoginModal();
      }
    },

    leaveGroup() {
      this.set("updatingMembership", true);

      if (this.model.public_admission) {
        this.removeFromGroup();
      } else {
        return this.dialog.yesNoConfirm({
          message: I18n.t("groups.confirm_leave"),
          didConfirm: () => this.removeFromGroup(),
          didCancel: () => this.set("updatingMembership", false),
        });
      }
    },

    showRequestMembershipForm() {
      if (this.currentUser) {
        showModal("request-group-membership-form", {
          model: this.model,
        });
      } else {
        this._showLoginModal();
      }
    },
  },
});
