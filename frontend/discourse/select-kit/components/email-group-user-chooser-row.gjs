import { classNames } from "@ember-decorators/component";
import decorateUsernameSelector from "discourse/helpers/decorate-username-selector";
import formatUsername from "discourse/helpers/format-username";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import { and } from "discourse/truth-helpers";
import DUserStatusMessage from "discourse/ui-kit/d-user-status-message";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@classNames("email-group-user-chooser-row")
export default class EmailGroupUserChooserRow extends SelectKitRowComponent {
  <template>
    {{#if this.item.isUser}}
      {{dAvatar this.item imageSize="tiny"}}
      <div>
        <span class="identifier">{{formatUsername this.item.id}}</span>
        <span class="name">{{this.item.name}}</span>
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
      <div>
        <span class="identifier">{{this.item.id}}</span>
        <span class="name">{{this.item.full_name}}</span>
      </div>
    {{else}}
      {{dIcon "envelope"}}
      <span class="identifier">{{this.item.id}}</span>
    {{/if}}
  </template>
}
