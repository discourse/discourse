import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import RequestGroupMembershipForm from "./modal/request-group-membership-form.gjs";

export default class GroupMembershipButton extends Component {
  @service appEvents;
  @service currentUser;
  @service dialog;
  @service modal;

  @tracked updatingMembership = false;

  get canJoinGroup() {
    return get(this.args.model, "public_admission") && !this.userIsGroupUser;
  }

  get canLeaveGroup() {
    return get(this.args.model, "public_exit") && this.userIsGroupUser;
  }

  get canRequestMembership() {
    return (
      get(this.args.model, "allow_membership_requests") && !this.userIsGroupUser
    );
  }

  get userIsGroupUser() {
    return !!get(this.args.model, "is_group_user");
  }

  removeFromGroup() {
    const model = this.args.model;
    model
      .leave()
      .then(() => {
        model.set("is_group_user", false);
        this.appEvents.trigger("group:leave", model);
      })
      .catch(popupAjaxError)
      .finally(() => (this.updatingMembership = false));
  }

  @action
  joinGroup() {
    if (!this.currentUser) {
      return this.args.showLogin();
    }

    this.updatingMembership = true;
    const group = this.args.model;

    group
      .join()
      .then(() => {
        group.set("is_group_user", true);
        this.appEvents.trigger("group:join", group);
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.updatingMembership = false;
      });
  }

  @action
  leaveGroup() {
    this.updatingMembership = true;

    if (this.args.model.public_admission) {
      this.removeFromGroup();
    } else {
      return this.dialog.yesNoConfirm({
        message: i18n("groups.confirm_leave"),
        didConfirm: () => this.removeFromGroup(),
        didCancel: () => {
          this.updatingMembership = false;
        },
      });
    }
  }

  @action
  showRequestMembershipForm() {
    if (!this.currentUser) {
      return this.args.showLogin();
    }

    this.modal.show(RequestGroupMembershipForm, {
      model: {
        group: this.args.model,
      },
    });
  }

  <template>
    <div class="group-membership-button" ...attributes>
      {{#if this.canJoinGroup}}
        <DButton
          class="btn-default group-index-join"
          @action={{this.joinGroup}}
          @disabled={{this.updatingMembership}}
          @icon="user-plus"
          @label="groups.join"
        />
      {{else if this.canLeaveGroup}}
        <DButton
          class="btn-danger group-index-leave"
          @action={{this.leaveGroup}}
          @disabled={{this.updatingMembership}}
          @icon="user-xmark"
          @label="groups.leave"
        />
      {{else if this.canRequestMembership}}
        <DButton
          class="btn-default group-index-request"
          @action={{this.showRequestMembershipForm}}
          @icon="user-plus"
          @label="groups.request"
        />
      {{else}}
        {{yield}}
      {{/if}}
    </div>
  </template>
}
