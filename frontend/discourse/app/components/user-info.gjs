/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { alias } from "@ember/object/computed";
import {
  attributeBindings,
  classNameBindings,
} from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import UserStatusMessage from "discourse/components/user-status-message";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import formatUsername from "discourse/helpers/format-username";
import lazyHash from "discourse/helpers/lazy-hash";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { userPath } from "discourse/lib/url";
import { and } from "discourse/truth-helpers";

@classNameBindings(":user-info", "size")
@attributeBindings("dataUsername:data-username")
export default class UserInfo extends Component {
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

  @computed("user.username")
  get userPath() {
    return userPath(this.user?.username);
  }

  @computed("user.name")
  get nameFirst() {
    return prioritizeNameInUx(this.user?.name);
  }

  <template>
    {{#if this.includeAvatar}}
      <div class="user-image">
        <div class="user-image-inner">
          <a
            href={{this.userPath}}
            data-user-card={{@user.username}}
            aria-hidden="true"
          >{{avatar @user imageSize="large"}}</a>
          <UserAvatarFlair @user={{@user}} />
        </div>
      </div>
    {{/if}}
    <div class="user-detail">
      <div
        class={{concatClass
          "name-line"
          (if @showStatus "--show-status")
          (if this.nameFirst "--name-first")
        }}
      >
        <span class="username-wrapper">
          {{#if this.includeLink}}
            <a
              href={{this.userPath}}
              data-user-card={{@user.username}}
              role={{if @headingLevel "heading"}}
              aria-level={{@headingLevel}}
            >
              <span class="username">{{formatUsername @user.username}}</span>
            </a>
          {{else}}
            <span class="username">{{formatUsername @user.username}}</span>
          {{/if}}
          {{#if (and @showStatus @user.status)}}
            <UserStatusMessage
              @status={{@user.status}}
              @showDescription={{@showStatusDescription}}
            />
          {{/if}}
        </span>
        {{#if @user.name}}
          <span class="name-wrapper">
            {{#if this.includeLink}}
              <a href={{this.userPath}} data-user-card={{@user.username}}>
                <span class="name">{{@user.name}}</span>
              </a>
            {{else}}
              <span class="name">{{@user.name}}</span>
            {{/if}}
          </span>
        {{/if}}
        <PluginOutlet
          @name="after-user-name"
          @connectorTagName="span"
          @outletArgs={{lazyHash user=this.user}}
        />
      </div>
      <div class="title">{{@user.title}}</div>
      {{#if (has-block)}}
        <div class="details">
          {{yield}}
        </div>
      {{/if}}
    </div>

    <PluginOutlet
      @name="after-user-info"
      @connectorTagName="div"
      @outletArgs={{lazyHash user=this.user}}
    />
  </template>
}
