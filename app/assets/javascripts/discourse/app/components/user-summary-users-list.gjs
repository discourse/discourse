import Component from "@ember/component";
import { concat } from "@ember/helper";
import iN from "discourse/helpers/i18n";

export default class UserSummaryUsersList extends Component {
  <template>
    {{#if this.users}}
      <ul>
        {{#each this.users as |user|}}
          {{yield user}}
        {{/each}}
      </ul>
    {{else}}
      <p>{{iN (concat "user.summary." this.none)}}</p>
    {{/if}}
  </template>
}
