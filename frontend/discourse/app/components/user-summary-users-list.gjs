/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { concat } from "@ember/helper";
import { tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@tagName("")
export default class UserSummaryUsersList extends Component {
  <template>
    <div ...attributes>
      {{#if this.users}}
        <ul>
          {{#each this.users as |user|}}
            {{yield user}}
          {{/each}}
        </ul>
      {{else}}
        <p>{{i18n (concat "user.summary." this.none)}}</p>
      {{/if}}
    </div>
  </template>
}
