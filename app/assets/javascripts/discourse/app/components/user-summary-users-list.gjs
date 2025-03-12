import Component from "@ember/component";
import { concat } from "@ember/helper";
import { i18n } from "discourse-i18n";

export default class UserSummaryUsersList extends Component {
  <template>
    {{#if this.users}}
      <ul>
        {{#each this.users as |user|}}
          {{yield user}}
        {{/each}}
      </ul>
    {{else}}
      <p>{{i18n (concat "user.summary." this.none)}}</p>
    {{/if}}
  </template>
}
