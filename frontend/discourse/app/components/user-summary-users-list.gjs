import { concat } from "@ember/helper";
import { i18n } from "discourse-i18n";

const UserSummaryUsersList = <template>
  <div ...attributes>
    {{#if @users}}
      <ul>
        {{#each @users as |user|}}
          {{yield user}}
        {{/each}}
      </ul>
    {{else}}
      <p>{{i18n (concat "user.summary." @none)}}</p>
    {{/if}}
  </div>
</template>;

export default UserSummaryUsersList;
