import Component from "@glimmer/component";
import { userPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";

export default class SolvedAdminReportTableSummaryItem extends Component {
  userProfilePath(user) {
    return userPath(user.username);
  }

  <template>
    <a
      class="solved-admin-report-table-summary__topic-link"
      href={{@item.topic.url}}
    >
      {{@item.topic.title}}
    </a>
    <div class="solved-admin-report-table-summary__topic-meta">
      {{#each @item.solved_by_users as |user|}}
        <a
          class="admin-report-table-summary__user-link"
          href={{this.userProfilePath user}}
        >
          {{dAvatar
            user
            imageSize="small"
            extraClasses="admin-report-table-summary__avatar"
          }}
          <span class="admin-report-table-summary__username">
            {{formatUsername user.username}}
          </span>
        </a>
      {{/each}}
      {{#if @item.category}}
        {{dCategoryBadge @item.category}}
      {{/if}}
    </div>
  </template>
}
