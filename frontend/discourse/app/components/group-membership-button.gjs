/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { service } from "discourse/lib/service";
import { tagName } from "@ember-decorators/component";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import AppEventsService from "discourse/services/app-events";
import CurrentUserService from "discourse/services/current-user";
import DialogService from "discourse/dialog-holder/services/dialog";
import ModalService from "discourse/services/modal";

@tagName("")
export default class GroupMembershipButton extends Component {
  @service(() => AppEventsService) appEvents;
  @service(() => CurrentUserService) currentUser;
  @service(() => DialogService) dialog;
  @service(() => ModalService) modal;

  @computed("model.public_admission", "userIsGroupUser")
  get canJoinGroup() {
    return this.model?.public_admission && !this.userIsGroupUser;
  }

  @computed("model.public_exit", "userIsGroupUser")
  get canLeaveGroup() {
    return this.model?.public_exit && this.userIsGroupUser;
  }

  @computed("model.allow_membership_requests", "userIsGroupUser")
  get canRequestMembership() {
    return this.model?.allow_membership_requests && !this.userIsGroupUser;
  }

  @computed("model.is_group_user")
  get userIsGroupUser() {
    return !!this.model?.is_group_user;
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
    if (!this.currentUser) {
      return this.showLogin();
    }

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
    if (!this.currentUser) {
      return this.showLogin();
    }

    this.modal.show(() => import("./modal/request-group-membership-form"), {
      model: {
        group: this.model,
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
          @disabled={{this.loading}}
          @icon="user-plus"
          @label="groups.request"
        />
      {{else}}
        {{yield}}
      {{/if}}
    </div>
  </template>
}
