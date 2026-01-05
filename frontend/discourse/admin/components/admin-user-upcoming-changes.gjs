import Component from "@glimmer/component";
import { array, concat } from "@ember/helper";
import AdminFilterControls from "discourse/admin/components/admin-filter-controls";
import SeparatedList from "discourse/components/separated-list";
import { UPCOMING_CHANGES_USER_ENABLED_REASONS } from "discourse/lib/constants";
import { bind } from "discourse/lib/decorators";
import { and, eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class AdminUserUpcomingChanges extends Component {
  @bind
  reasonKey(reason) {
    return `user.upcoming_changes.why_reasons.${reason}`;
  }

  <template>
    <AdminFilterControls
      @array={{@user.upcoming_changes_stats}}
      @searchableProps={{array "humanized_name" "description"}}
      @inputPlaceholder={{i18n
        "admin.user.upcoming_changes.filter_placeholder"
      }}
      @noResultsMessage={{i18n "admin.user.upcoming_changes.filter_no_results"}}
    >
      <:content as |filteredChanges|>
        <table class="d-table user-upcoming-changes-table">
          <thead class="d-table__header">
            <th>{{i18n "user.upcoming_changes.for_user.upcoming_change"}}</th>
            <th>{{i18n "user.upcoming_changes.for_user.enabled"}}</th>
            <th>{{i18n "user.upcoming_changes.for_user.why"}}</th>
          </thead>
          <tbody class="d-table__body">
            {{#each filteredChanges as |upcomingChange|}}
              <tr
                class="d-table__row"
                data-upcoming-change-name={{upcomingChange.name}}
              >
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
                <td class="d-table__cell">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "user.upcoming_changes.for_user.enabled"}}
                  </div>

                  <span class="upcoming-change-enabled-status">
                    {{if
                      upcomingChange.enabled
                      (i18n "yes_value")
                      (i18n "no_value")
                    }}
                  </span>
                </td>
                <td class="d-table__cell">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "user.upcoming_changes.for_user.why"}}
                  </div>

                  <span class="upcoming-change-reason">
                    {{i18n
                      (this.reasonKey upcomingChange.reason)
                      username=@user.username
                    }}
                  </span>
                  {{#if
                    (and
                      (eq
                        upcomingChange.reason
                        UPCOMING_CHANGES_USER_ENABLED_REASONS.in_specific_groups
                      )
                      upcomingChange.specific_groups.length
                    )
                  }}
                    (<SeparatedList
                      @items={{upcomingChange.specific_groups}}
                      @separator=", "
                      class="upcoming-change-groups"
                      as |group|
                    >
                      <a href={{concat "/g/" group}}>{{group}}</a>
                    </SeparatedList>)
                  {{/if}}
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </:content>
    </AdminFilterControls>
  </template>
}
