import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";
import UserFlagPercentage from "discourse/components/user-flag-percentage";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import FlagUser from "admin/components/flag-user";
import dispositionIcon from "admin/helpers/disposition-icon";
import postActionTitle from "admin/helpers/post-action-title";

@classNames("flag-user-lists")
export default class FlagUserLists extends Component {
  <template>
    <div class="flagged-by">
      <div class="user-list-title">
        {{i18n "admin.flags.flagged_by"}}
      </div>
      <div class="flag-users">
        {{#each this.flaggedPost.post_actions as |postAction|}}
          <FlagUser @user={{postAction.user}} @date={{postAction.created_at}}>
            <div class="flagger-flag-type">
              {{postActionTitle
                postAction.post_action_type_id
                postAction.name_key
              }}
            </div>
            <UserFlagPercentage
              @agreed={{postAction.user.flags_agreed}}
              @disagreed={{postAction.user.flags_disagreed}}
              @ignored={{postAction.user.flags_ignored}}
            />
          </FlagUser>
        {{/each}}
      </div>
    </div>

    {{#if this.showResolvedBy}}
      <div class="flagged-post-resolved-by">
        <div class="user-list-title">
          {{i18n "admin.flags.resolved_by"}}
        </div>
        <div class="flag-users">
          {{#each this.flaggedPost.post_actions as |postAction|}}
            <FlagUser
              @user={{postAction.disposed_by}}
              @date={{postAction.disposed_at}}
            >
              {{dispositionIcon postAction.disposition}}
              {{#if postAction.staff_took_action}}
                {{icon "gavel" title="admin.flags.took_action"}}
              {{/if}}
            </FlagUser>
          {{/each}}
        </div>
      </div>
    {{/if}}
  </template>
}
