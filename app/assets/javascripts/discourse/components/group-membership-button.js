import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  classNames: ["group-membership-button"],

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
    $.cookie("destination_url", window.location.href);
  },

  removeFromGroup() {
    this.model
      .removeMember(this.currentUser)
      .then(() => this.model.set("is_group_user", false))
      .catch(popupAjaxError)
      .finally(() => this.set("updatingMembership", false));
  },

  actions: {
    joinGroup() {
      if (this.currentUser) {
        this.set("updatingMembership", true);
        const model = this.model;

        model
          .addMembers(this.currentUser.get("username"))
          .then(() => {
            model.set("is_group_user", true);
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
        return bootbox.confirm(
          I18n.t("groups.confirm_leave"),
          I18n.t("no_value"),
          I18n.t("yes_value"),
          result => {
            result
              ? this.removeFromGroup()
              : this.set("updatingMembership", false);
          }
        );
      }
    },

    showRequestMembershipForm() {
      if (this.currentUser) {
        showModal("request-group-membership-form", {
          model: this.model
        });
      } else {
        this._showLoginModal();
      }
    }
  }
});
