import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { groupPath } from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DUserLink from "discourse/ui-kit/d-user-link";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class PrivateMessageMap extends Component {
  @service site;

  get participantsClasses() {
    return this.site.mobileView &&
      this.args.topicDetails.allowed_groups.length > 4
      ? "participants hide-names"
      : "participants";
  }

  get canInvite() {
    return this.args.topicDetails.can_invite_to;
  }

  get canRemove() {
    return (
      this.args.topicDetails.can_remove_allowed_users ||
      this.args.topicDetails.can_remove_self_id
    );
  }

  get canShowControls() {
    return this.canInvite || this.canRemove;
  }

  <template>
    <div class={{this.participantsClasses}}>
      {{#each @topicDetails.allowed_groups as |group|}}
        <PmMapUserGroup
          @canRemoveAllowedUsers={{@topicDetails.can_remove_allowed_users}}
          @model={{group}}
          @removeAllowedGroup={{@removeAllowedGroup}}
        />
      {{/each}}
      {{#each @topicDetails.allowed_users as |user|}}
        <PmMapUser
          @canRemoveAllowedUsers={{@topicDetails.can_remove_allowed_users}}
          @canRemoveSelfId={{@topicDetails.can_remove_self_id}}
          @model={{user}}
          @removeAllowedUser={{@removeAllowedUser}}
        />
      {{/each}}

      {{#if this.canInvite}}
        <DButton
          class="btn-default btn-small add-participant-btn"
          @action={{@showInvite}}
          @icon="plus"
        />
      {{/if}}
    </div>
  </template>
}

class PmMapUserGroup extends Component {
  get canRemoveLink() {
    return this.args.canRemoveAllowedUsers;
  }

  get groupUrl() {
    return groupPath(this.args.model.name);
  }

  <template>
    <div class="user group btn-default" data-id={{@model.id}}>
      <a class="group-link" href={{this.groupUrl}}>
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
  @action
  removeGroup() {
    this.args.removeAllowedGroup(this.args.model);
  }

  <template>
    <DButton
      class="btn-transparent remove-invited btn-small"
      @action={{this.removeGroup}}
      @icon="xmark"
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
    return this.args.canRemoveAllowedUsers || this.isCurrentUser;
  }

  <template>
    <div class="user btn-default" data-id={{@model.id}}>
      <DUserLink
        class="user-link trigger-user-card"
        title={{@model.username}}
        @href={{@model.path}}
        @username={{@model.username}}
      >
        {{dBoundAvatarTemplate
          @model.avatar_template
          "tiny"
          (hash title=this.avatarTitle)
        }}
        <span class="username">{{@model.username}}</span>
      </DUserLink>

      {{#if this.canRemoveLink}}
        <PmRemoveLink
          @isCurrentUser={{this.isCurrentUser}}
          @model={{@model}}
          @removeAllowedUser={{@removeAllowedUser}}
        />
      {{/if}}
    </div>
  </template>
}

class PmRemoveLink extends Component {
  @action
  removeUser() {
    this.args.removeAllowedUser(this.args.model);
  }

  <template>
    <DButton
      class="btn-transparent remove-invited btn-small"
      @action={{this.removeUser}}
      @icon="xmark"
    />
  </template>
}
