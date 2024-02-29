import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import { groupPath } from "discourse/lib/url";
import dIcon from "discourse-common/helpers/d-icon";
import { tinyAvatar } from "discourse-common/lib/avatar-utils";
import I18n from "discourse-i18n";
import and from "truth-helpers/helpers/and";

export default class PrivateMessageMap extends Component {
  @service site;
  @tracked isEditing = false;

  get participantsClasses() {
    if (
      !this.isEditing &&
      this.site.mobileView &&
      this.args.postAttrs.allowedGroups.length > 4
    ) {
      return "participants hide-names";
    }
    return "participants";
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
    return this._actionMap[this._actionAllowedKey()].bind(this);
  }

  _actionAllowedKey() {
    if (this.canInvite && this.canRemove) {
      return "edit";
    }
    if (!this.canInvite && this.canRemove) {
      return "remove";
    }
    return "add";
  }

  get _actionMap() {
    return {
      edit: this.toggleEditing,
      remove: this.toggleEditing,
      add: this.args.showInvite,
    };
  }

  get actionAllowedLabel() {
    return `private_message_info.${this._actionAllowedKey()}`;
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
          class="btn btn-default add-remove-participant-btn"
        />

        {{#if (and this.canInvite this.isEditing)}}
          <DButton
            @action={{@showInvite}}
            @icon="plus"
            class="btn btn-default no-text btn-icon add-participant-btn"
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
    </div>
    {{#if this.canRemoveLink}}
      <PmRemoveGroupLink
        @model={{@model}}
        @removeAllowedGroup={{@removeAllowedGroup}}
      />
    {{/if}}
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
    {{! template-lint-disable no-invalid-interactive }}
    <a
      class="remove-invited no-text btn-icon btn"
      {{on "click" this.showConfirmDialog}}
    >
      {{dIcon "times"}}
    </a>
  </template>
}

class PmMapUser extends Component {
  @service site;

  get linkClass() {
    if (this.site.mobileView) {
      return "";
    }
    return "user-link";
  }

  get userUrl() {
    return this.args.model.path;
  }

  get avatarImage() {
    return htmlSafe(
      tinyAvatar(this.args.model.avatar_template, {
        title: this.args.model.name || this.args.model.username,
      })
    );
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
      <a class={{this.linkClass}} href={{this.userUrl}}>
        {{#if this.site.mobileView}}
          {{this.avatarImage}}
        {{else}}
          <a
            class="trigger-user-card"
            data-user-card={{@model.username}}
            title={{@model.username}}
            aria-hidden="true"
          >
            {{this.avatarImage}}
          </a>
        {{/if}}
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
      ? "leave_message"
      : "remove_allowed_user";

    this.dialog.deleteConfirm({
      message: I18n.t(`private_message_info.${messageKey}`, {
        name: this.args.model.username,
      }),
      confirmButtonLabel: this.args.isCurrentUser
        ? "private_message_info.leave"
        : "private_message_info.remove_user",
      didConfirm: () => this.args.removeAllowedUser(this.args.model),
    });
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <a
      class="remove-invited no-text btn-icon btn"
      {{on "click" this.showConfirmDialog}}
    >
      {{dIcon "times"}}
    </a>
  </template>
}
