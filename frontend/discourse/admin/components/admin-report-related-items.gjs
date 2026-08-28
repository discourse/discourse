import Component from "@glimmer/component";
import { adminReportRelatedItemsRenderer } from "discourse/admin/lib/admin-report-related-items";
import { userPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default class AdminReportRelatedItems extends Component {
  get users() {
    return this.args.relatedItems?.users || [];
  }

  get userDescriptionKey() {
    return `admin.reports.related_items.users.${this.args.type}.description`;
  }

  get userTimestampLabelKey() {
    return this.args.type === "new_contributors"
      ? "admin.reports.related_items.labels.first_post"
      : "admin.reports.related_items.labels.created_at";
  }

  get relatedItemsComponent() {
    return adminReportRelatedItemsRenderer(this.args.type)
      ?.relatedItemsComponent;
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

  <template>
    {{#if this.users.length}}
      <section class="admin-report-related-items">
        <h2>{{i18n "admin.reports.related_items.users.title"}}</h2>
        <p class="admin-report-related-items__description">
          {{i18n
            this.userDescriptionKey
            startDate=this.startDate
            endDate=this.endDate
          }}
        </p>

        <table class="table admin-report-related-items__table">
          <thead>
            <tr>
              <th class="admin-report-related-items__user-cell">
                {{i18n "admin.reports.related_items.labels.user"}}
              </th>
              <th class="admin-report-related-items__timestamp-cell">
                {{i18n this.userTimestampLabelKey}}
              </th>
            </tr>
          </thead>
          <tbody>
            {{#each this.users as |item|}}
              <tr>
                <td class="admin-report-related-items__user-cell">
                  <a
                    class="admin-report-related-items__user-link"
                    href={{this.userProfilePath item.user}}
                  >
                    {{dAvatar
                      item.user
                      imageSize="small"
                      extraClasses="admin-report-related-items__avatar"
                    }}
                    <span class="admin-report-related-items__user-identity">
                      <span class="admin-report-related-items__username">
                        {{formatUsername item.user.username}}
                      </span>
                      {{#if item.user.name}}
                        <span class="admin-report-related-items__name">
                          {{item.user.name}}
                        </span>
                      {{/if}}
                    </span>
                  </a>
                </td>
                <td class="admin-report-related-items__timestamp-cell">
                  <time datetime={{item.timestamp}}>
                    {{dFormatDate item.timestamp format="medium"}}
                  </time>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </section>
    {{/if}}

    {{#if this.relatedItemsComponent}}
      {{component
        this.relatedItemsComponent
        relatedItems=@relatedItems
        startDate=@startDate
        endDate=@endDate
      }}
    {{/if}}
  </template>
}
