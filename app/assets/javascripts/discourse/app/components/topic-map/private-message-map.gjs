import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { and } from "truth-helpers";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/bound-avatar-template";
import { groupPath } from "discourse/lib/url";
import dIcon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";

export default class PrivateMessageMap extends Component {
  @service site;
  @tracked isEditing = false;

  get participantsClasses() {
    return !this.isEditing &&
      this.site.mobileView &&
      this.args.postAttrs.allowedGroups.length > 4
      ? "participants hide-names"
      : "participants";
  }

  get canInvite() {
    return this.args.postAttrs.canInvite;
  }

  get canRemove() {
    return (
      this.args.postAttrs.canRemoveAllowedUsers ||
      this.args.postAttrs.canRemoveSelfId
    );
  }

  get canShowControls() {
    return this.canInvite || this.canRemove;
  }

  get actionAllowed() {
    return this.canRemove ? this.toggleEditing : this.args.showInvite;
  }

  get actionAllowedLabel() {
    if (this.canInvite && this.canRemove) {
      return "private_message_info.edit";
    }
    if (!this.canInvite && this.canRemove) {
      return "private_message_info.remove";
    }
    return "private_message_info.add";
  }

  @action
  toggleEditing() {
    this.isEditing = !this.isEditing;
  }

  <template>
    <div class={{this.participantsClasses}}>
      {{#each @postAttrs.allowedGroups as |group|}}
        <PmMapUserGroup
          @model={{group}}
          @isEditing={{this.isEditing}}
          @canRemoveAllowedUsers={{@postAttrs.canRemoveAllowedUsers}}
          @removeAllowedGroup={{@removeAllowedGroup}}
        />
      {{/each}}
      {{#each @postAttrs.allowedUsers as |user|}}
        <PmMapUser
          @model={{user}}
          @isEditing={{this.isEditing}}
          @canRemoveAllowedUsers={{@postAttrs.canRemoveAllowedUsers}}
          @canRemoveSelfId={{@postAttrs.canRemoveSelfId}}
          @removeAllowedUser={{@removeAllowedUser}}
        />
      {{/each}}
    </div>

    {{#if this.canShowControls}}
      <div class="controls">
        <DButton
          @action={{this.actionAllowed}}
          @label={{this.actionAllowedLabel}}
          class="btn-default add-remove-participant-btn"
        />

        {{#if (and this.canInvite this.isEditing)}}
          <DButton
            @action={{@showInvite}}
            @icon="plus"
            class="btn-default add-participant-btn"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}

class PmMapUserGroup extends Component {
  get canRemoveLink() {
    return this.args.isEditing && this.args.canRemoveAllowedUsers;
  }

  get groupUrl() {
    return groupPath(this.args.model.name);
  }

  <template>
    <div class="user group">
      <a href={{this.groupUrl}} class="group-link">
        {{dIcon "users"}}
        <span class="group-name">{{@model.name}}</span>
      </a>
      {{#if this.canRemoveLink}}
        <PmRemoveGroupLink
          @model={{@model}}
          @removeAllowedGroup={{@removeAllowedGroup}}
        />
      {{/if}}
    </div>
  </template>
}

class PmRemoveGroupLink extends Component {
  @service dialog;

  @action
  showConfirmDialog() {
    this.dialog.deleteConfirm({
      message: I18n.t("private_message_info.remove_allowed_group", {
        name: this.args.model.name,
      }),
      confirmButtonLabel: "private_message_info.remove_group",
      didConfirm: () => this.args.removeAllowedGroup(this.args.model),
    });
  }

  <template>
    <DButton
      class="remove-invited"
      @action={{this.showConfirmDialog}}
      @icon="times"
    />
  </template>
}

class PmMapUser extends Component {
  get avatarTitle() {
    return this.args.model.name || this.args.model.username;
  }

  get isCurrentUser() {
    return this.args.canRemoveSelfId === this.args.model.id;
  }

  get canRemoveLink() {
    return (
      this.args.isEditing &&
      (this.args.canRemoveAllowedUsers || this.isCurrentUser)
    );
  }

  <template>
    <div class="user">
      <a class="user-link" href={{@model.path}}>
        <a
          class="trigger-user-card"
          data-user-card={{@model.username}}
          title={{@model.username}}
          aria-hidden="true"
        >
          {{avatar @model.avatar_template "tiny" (hash title=this.avatarTitle)}}
        </a>
        <span class="username">{{@model.username}}</span>
      </a>

      {{#if this.canRemoveLink}}
        <PmRemoveLink
          @model={{@model}}
          @isCurrentUser={{this.isCurrentUser}}
          @removeAllowedUser={{@removeAllowedUser}}
        />
      {{/if}}
    </div>
  </template>
}

class PmRemoveLink extends Component {
  @service dialog;

  @action
  showConfirmDialog() {
    const messageKey = this.args.isCurrentUser
      ? "private_message_info.leave_message"
      : "private_message_info.remove_allowed_user";

    this.dialog.deleteConfirm({
      message: I18n.t(messageKey, {
        name: this.args.model.username,
      }),
      confirmButtonLabel: this.args.isCurrentUser
        ? "private_message_info.leave"
        : "private_message_info.remove_user",
      didConfirm: () => this.args.removeAllowedUser(this.args.model),
    });
  }
  <template>
    <DButton
      class="remove-invited"
      @action={{this.showConfirmDialog}}
      @icon="times"
    />
  </template>
}
