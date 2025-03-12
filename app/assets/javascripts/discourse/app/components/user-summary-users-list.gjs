import Component from "@ember/component";

export default class UserSummaryUsersList extends Component {}

{{#if this.users}}
  <ul>
    {{#each this.users as |user|}}
      {{yield user}}
    {{/each}}
  </ul>
{{else}}
  <p>{{i18n (concat "user.summary." this.none)}}</p>
{{/if}}