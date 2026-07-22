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

  get groupNameOrdering() {
    if (!this.selectKit.options.prioritizeGroupFullNameOrdering) {
      return "groupNameFirst";
    }

    return "groupFullNameFirst";
  }

  get shouldExcludeGroupName() {
    return (
      this.selectKit.options.excludeGroupNameWhenMatchingFullName &&
      this.item.full_name.toLowerCase() ===
        this.item.id.toLowerCase().replaceAll("_", " ").replaceAll("-", " ")
    );
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
          {{#if this.item.name}}
            <span class="name">{{this.item.name}}</span>
          {{/if}}
        {{else}}
          {{#if this.item.name}}
            <span class="name">{{this.item.name}}</span>
          {{/if}}
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
          (if
            (eq this.groupNameOrdering "groupNameFirst")
            "--group-name-first"
            "--group-full-name-first"
          )
        }}
      >
        {{#if (eq this.groupNameOrdering "groupNameFirst")}}
          {{#unless this.shouldExcludeGroupName}}
            <span class="identifier">{{this.item.id}}</span>
          {{/unless}}
          <span class="name">{{this.item.full_name}}</span>
        {{else}}
          <span class="name">{{this.item.full_name}}</span>
          {{#unless this.shouldExcludeGroupName}}
            <span class="identifier">{{this.item.id}}</span>
          {{/unless}}
        {{/if}}
      </div>
    {{else}}
      {{dIcon "envelope"}}
      <span class="identifier">{{this.item.id}}</span>
    {{/if}}
  </template>
}
