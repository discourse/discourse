import { classNames } from "@ember-decorators/component";
import decorateUsernameSelector from "discourse/helpers/decorate-username-selector";
import formatUsername from "discourse/helpers/format-username";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import { and, eq } from "discourse/truth-helpers";
import DUserStatusMessage from "discourse/ui-kit/d-user-status-message";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@classNames("email-group-user-chooser-row")
export default class EmailGroupUserChooserRow extends SelectKitRowComponent {
  get userNameOrdering() {
    if (
      !this.selectKit.options.prioritizeUserNameOrdering ||
      this.siteSettings.prioritize_username_in_ux
    ) {
      return "usernameFirst";
    }

    return "nameFirst";
  }

  <template>
    {{#if this.item.isUser}}
      {{dAvatar this.item imageSize="tiny"}}
      <div
        class={{dConcatClass
          "email-group-user-chooser--user"
          (if
            (eq this.userNameOrdering "usernameFirst")
            "--username-first"
            "--name-first"
          )
        }}
      >
        {{#if (eq this.userNameOrdering "usernameFirst")}}
          <span class="identifier">{{formatUsername this.item.id}}</span>
          <span class="name">{{this.item.name}}</span>
        {{else}}
          <span class="name">{{this.item.name}}</span>
          <span class="identifier">{{formatUsername this.item.id}}</span>
        {{/if}}
      </div>
      {{#if (and this.item.showUserStatus this.item.status)}}
        <DUserStatusMessage
          @status={{this.item.status}}
          @showDescription={{true}}
        />
      {{/if}}
      {{decorateUsernameSelector this.item.id}}
    {{else if this.item.isGroup}}
      {{dIcon "users"}}
      <div
        class={{dConcatClass
          "email-group-user-chooser--group"
          (if this.selectKit.options.onlyShowGroupName "--name-only")
        }}
      >
        {{#unless this.selectKit.options.onlyShowGroupName}}
          <span class="identifier">{{this.item.id}}</span>
        {{/unless}}
        <span class="name">
          {{#if this.selectKit.options.onlyShowGroupName}}
            {{#if this.item.full_name}}
              {{this.item.full_name}}
            {{else}}
              {{this.item.name}}
            {{/if}}
          {{else}}
            {{this.item.name}}
          {{/if}}
        </span>
      </div>
    {{else}}
      {{dIcon "envelope"}}
      <span class="identifier">{{this.item.id}}</span>
    {{/if}}
  </template>
}
