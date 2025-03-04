import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { attributeBindings, classNameBindings } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { userPath } from "discourse/lib/url";
import avatar from "discourse/helpers/avatar";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import formatUsername from "discourse/helpers/format-username";
import and from "truth-helpers/helpers/and";
import UserStatusMessage from "discourse/components/user-status-message";
import PluginOutlet from "discourse/components/plugin-outlet";
import { hash } from "@ember/helper";

@classNameBindings(":user-info", "size")
@attributeBindings("dataUsername:data-username")
export default class UserInfo extends Component {<template>{{#if this.includeAvatar}}
  <div class="user-image">
    <div class="user-image-inner">
      <a href={{this.userPath}} data-user-card={{@user.username}} aria-hidden="true">{{avatar @user imageSize="large"}}</a>
      <UserAvatarFlair @user={{@user}} />
    </div>
  </div>
{{/if}}
<div class="user-detail">
  <div class="name-line">
    {{#if this.includeLink}}
      <a href={{this.userPath}} data-user-card={{@user.username}} role="heading">
        <span class={{if this.nameFirst "name" "username"}}>
          {{if this.nameFirst @user.name (formatUsername @user.username)}}
        </span>
        <span class={{if this.nameFirst "username" "name"}}>
          {{if this.nameFirst (formatUsername @user.username) @user.name}}
        </span>
      </a>
    {{else}}
      <span class={{if this.nameFirst "name" "username"}}>
        {{if this.nameFirst @user.name (formatUsername @user.username)}}
      </span>
      <span class={{if this.nameFirst "username" "name"}}>
        {{if this.nameFirst (formatUsername @user.username) @user.name}}
      </span>
    {{/if}}
    {{#if (and @showStatus @user.status)}}
      <UserStatusMessage @status={{@user.status}} @showDescription={{@showStatusDescription}} />
    {{/if}}
    <PluginOutlet @name="after-user-name" @connectorTagName="span" @outletArgs={{hash user=this.user}} />
  </div>
  <div class="title">{{@user.title}}</div>
  {{#if (has-block)}}
    <div class="details">
      {{yield}}
    </div>
  {{/if}}
</div>

<PluginOutlet @name="after-user-info" @connectorTagName="div" @outletArgs={{hash user=this.user}} /></template>
  size = "small";
  includeLink = true;
  includeAvatar = true;

  @alias("user.username") dataUsername;

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.user?.statusManager?.trackStatus();
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.user?.statusManager?.stopTrackingStatus();
  }

  @discourseComputed("user.username")
  userPath(username) {
    return userPath(username);
  }

  @discourseComputed("user.name")
  nameFirst(name) {
    return prioritizeNameInUx(name);
  }
}
