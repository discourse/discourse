import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import cookie from "discourse/lib/cookie";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import RequestGroupMembershipForm from "./modal/request-group-membership-form";

@classNames("group-membership-button")
export default class GroupMembershipButton extends Component {
  @service appEvents;
  @service currentUser;
  @service dialog;
  @service modal;

  @discourseComputed("model.public_admission", "userIsGroupUser")
  canJoinGroup(publicAdmission, userIsGroupUser) {
    return publicAdmission && !userIsGroupUser;
  }

  @discourseComputed("model.public_exit", "userIsGroupUser")
  canLeaveGroup(publicExit, userIsGroupUser) {
    return publicExit && userIsGroupUser;
  }

  @discourseComputed("model.allow_membership_requests", "userIsGroupUser")
  canRequestMembership(allowMembershipRequests, userIsGroupUser) {
    return allowMembershipRequests && !userIsGroupUser;
  }

  @discourseComputed("model.is_group_user")
  userIsGroupUser(isGroupUser) {
    return !!isGroupUser;
  }

  _showLoginModal() {
    this.showLogin();
    cookie("destination_url", window.location.href);
  }

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
  }

  @action
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
  }

  @action
  leaveGroup() {
    this.set("updatingMembership", true);

    if (this.model.public_admission) {
      this.removeFromGroup();
    } else {
      return this.dialog.yesNoConfirm({
        message: i18n("groups.confirm_leave"),
        didConfirm: () => this.removeFromGroup(),
        didCancel: () => this.set("updatingMembership", false),
      });
    }
  }

  @action
  showRequestMembershipForm() {
    if (this.currentUser) {
      this.modal.show(RequestGroupMembershipForm, {
        model: {
          group: this.model,
        },
      });
    } else {
      this._showLoginModal();
    }
  }

  <template>
    {{#if this.canJoinGroup}}
      <DButton
        @action={{this.joinGroup}}
        @icon="user-plus"
        @label="groups.join"
        @disabled={{this.updatingMembership}}
        class="btn-default group-index-join"
      />
    {{else if this.canLeaveGroup}}
      <DButton
        @action={{this.leaveGroup}}
        @icon="user-xmark"
        @label="groups.leave"
        @disabled={{this.updatingMembership}}
        class="btn-danger group-index-leave"
      />
    {{else if this.canRequestMembership}}
      <DButton
        @action={{this.showRequestMembershipForm}}
        @disabled={{this.loading}}
        @icon="user-plus"
        @label="groups.request"
        class="btn-default group-index-request"
      />
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
