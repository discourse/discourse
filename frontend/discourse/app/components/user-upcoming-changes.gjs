import { concat } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const UserUpcomingChanges = <template>
  <table class="d-table user-upcoming-changes-table">
    <thead class="d-table__header">
      <th>{{i18n "user.upcoming_changes.for_user.upcoming_change"}}</th>
      <th>{{i18n "user.upcoming_changes.for_user.enabled"}}</th>
      <th>{{i18n "user.upcoming_changes.for_user.why"}}</th>
    </thead>
    <tbody class="d-table__body">
      {{#each @upcomingChangeStats as |upcomingChange|}}
        <tr class="d-table__row">
          <td class="d-table__cell --overview">
            <div class="d-table__overview-name">
              {{upcomingChange.humanized_name}}
            </div>
            {{#if upcomingChange.description}}
              <div class="d-table__overview-about">
                {{upcomingChange.description}}
              </div>
            {{/if}}
          </td>
          <td class="d-table__cell">{{if
              upcomingChange.enabled
              (i18n "yes_value")
              (i18n "no_value")
            }}</td>
          <td class="d-table__cell">{{i18n
              (concat
                "user.upcoming_changes.why_reasons." upcomingChange.reason
              )
            }}
            {{#if (eq upcomingChange.reason "in_specific_groups")}}
              {{#each upcomingChange.specific_groups as |group|}}
                <LinkTo @route="group.index" @model={{group}}>{{group}}</LinkTo>
              {{/each}}
            {{/if}}
          </td>
        </tr>
      {{/each}}
    </tbody>
  </table>
</template>;

export default UserUpcomingChanges;
