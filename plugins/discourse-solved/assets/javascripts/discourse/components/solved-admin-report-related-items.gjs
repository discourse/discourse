import Component from "@glimmer/component";
import { userPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import { i18n } from "discourse-i18n";

export default class SolvedAdminReportRelatedItems extends Component {
  get solvedTopics() {
    return this.args.relatedItems?.solved_topics || [];
  }

  get startDate() {
    return moment(this.args.startDate).format(
      i18n("dates.long_with_year_no_time")
    );
  }

  get endDate() {
    return moment(this.args.endDate).format(
      i18n("dates.long_with_year_no_time")
    );
  }

  userProfilePath(user) {
    return userPath(user.username);
  }

  solvedByUsers(item) {
    return item.solved_by_users || (item.solved_by ? [item.solved_by] : []);
  }

  <template>
    {{#if this.solvedTopics.length}}
      <section
        class="admin-report-related-items solved-admin-report-related-items"
      >
        <h2>{{i18n "admin.reports.related_items.solved_topics.title"}}</h2>
        <p class="admin-report-related-items__description">
          {{i18n
            "admin.reports.related_items.solved_topics.description"
            startDate=this.startDate
            endDate=this.endDate
          }}
        </p>

        <table class="table admin-report-related-items__table">
          <thead>
            <tr>
              <th class="solved-admin-report-related-items__topic-cell">
                {{i18n "admin.reports.related_items.labels.topic"}}
              </th>
              <th class="solved-admin-report-related-items__solved-by-cell">
                {{i18n "admin.reports.related_items.labels.solved_by"}}
              </th>
              <th class="solved-admin-report-related-items__category-cell">
                {{i18n "admin.reports.related_items.labels.category"}}
              </th>
            </tr>
          </thead>
          <tbody>
            {{#each this.solvedTopics as |item|}}
              <tr>
                <td class="solved-admin-report-related-items__topic-cell">
                  <a
                    class="solved-admin-report-related-items__topic-link"
                    href={{item.topic.url}}
                  >
                    {{item.topic.title}}
                  </a>
                </td>
                <td class="solved-admin-report-related-items__solved-by-cell">
                  {{#let (this.solvedByUsers item) as |users|}}
                    {{#if users.length}}
                      <div
                        class="solved-admin-report-related-items__solved-by-users"
                      >
                        {{#each users as |user|}}
                          <a
                            class="admin-report-related-items__user-link"
                            href={{this.userProfilePath user}}
                          >
                            {{dAvatar
                              user
                              imageSize="small"
                              extraClasses="admin-report-related-items__avatar"
                            }}
                            <span class="admin-report-related-items__username">
                              {{formatUsername user.username}}
                            </span>
                          </a>
                        {{/each}}
                      </div>
                    {{/if}}
                  {{/let}}
                </td>
                <td class="solved-admin-report-related-items__category-cell">
                  {{#if item.category}}
                    {{dCategoryBadge item.category}}
                  {{else}}
                    {{i18n "category.none"}}
                  {{/if}}
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </section>
    {{/if}}
  </template>
}
