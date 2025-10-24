import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/bound-avatar-template";
import icon from "discourse/helpers/d-icon";
import { groupPath } from "discourse/lib/url";

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
          @model={{group}}
          @canRemoveAllowedUsers={{@topicDetails.can_remove_allowed_users}}
          @removeAllowedGroup={{@removeAllowedGroup}}
        />
      {{/each}}
      {{#each @topicDetails.allowed_users as |user|}}
        <PmMapUser
          @model={{user}}
          @canRemoveAllowedUsers={{@topicDetails.can_remove_allowed_users}}
          @canRemoveSelfId={{@topicDetails.can_remove_self_id}}
          @removeAllowedUser={{@removeAllowedUser}}
        />
      {{/each}}

      {{#if this.canInvite}}
        <DButton
          @action={{@showInvite}}
          @icon="plus"
          class="btn-default btn-small add-participant-btn"
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
    <div class="user group" data-id={{@model.id}}>
      <a href={{this.groupUrl}} class="group-link">
        {{icon "users"}}
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
      class="remove-invited btn-small"
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
    <div class="user" data-id={{@model.id}}>
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
  @action
  removeUser() {
    this.args.removeAllowedUser(this.args.model);
  }

  <template>
    <DButton
      class="remove-invited btn-small"
      @action={{this.removeUser}}
      @icon="xmark"
    />
  </template>
}
