import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { UPCOMING_CHANGES_USER_ENABLED_REASONS } from "discourse/lib/constants";
import { bind } from "discourse/lib/decorators";
import { and, eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class UserUpcomingChanges extends Component {
  @service currentUser;

  @bind
  reasonKey(reason) {
    if (this.currentUser.id !== this.args.user.id) {
      if (
        reason === UPCOMING_CHANGES_USER_ENABLED_REASONS.in_specific_groups ||
        reason === UPCOMING_CHANGES_USER_ENABLED_REASONS.not_in_specific_groups
      ) {
        return `user.upcoming_changes.why_reasons.viewing_other_user.${reason}`;
      } else {
        return `user.upcoming_changes.why_reasons.${reason}`;
      }
    } else {
      return `user.upcoming_changes.why_reasons.${reason}`;
    }
  }

  <template>
    <table class="d-table user-upcoming-changes-table">
      <thead class="d-table__header">
        <th>{{i18n "user.upcoming_changes.for_user.upcoming_change"}}</th>
        <th>{{i18n "user.upcoming_changes.for_user.enabled"}}</th>
        <th>{{i18n "user.upcoming_changes.for_user.why"}}</th>
      </thead>
      <tbody class="d-table__body">
        {{#each @user.upcoming_changes_stats as |upcomingChange|}}
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
                (this.reasonKey upcomingChange.reason)
                username=@user.username
              }}
              {{#if
                (and
                  (eq
                    upcomingChange.reason
                    UPCOMING_CHANGES_USER_ENABLED_REASONS.in_specific_groups
                  )
                  upcomingChange.specific_groups.length
                )
              }}
                ({{#each upcomingChange.specific_groups as |group|}}
                  <LinkTo
                    @route="group.index"
                    @model={{group}}
                  >{{group}}</LinkTo>
                {{/each}})
              {{/if}}
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </template>
}
