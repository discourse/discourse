import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dElement from "discourse/ui-kit/helpers/d-element";
import { i18n } from "discourse-i18n";

const SUMMARY_LIMIT = 5;

export default class SolvedAdminReportTableSummary extends Component {
  @tracked items = null;
  @tracked isLoading = false;
  @tracked hasError = false;

  get date() {
    return moment.utc(this.args.date).format("YYYY-MM-DD");
  }

  get dateLabel() {
    return moment
      .utc(this.args.date)
      .format(i18n("dates.long_with_year_no_time"));
  }

  get triggerLabel() {
    return i18n("admin.reports.related_items.table_summary.trigger", {
      date: this.dateLabel,
    });
  }

  get title() {
    return i18n(
      "admin.reports.related_items.table_summary.solved_topics_title",
      { date: this.dateLabel }
    );
  }

  get hasItems() {
    return this.items?.length > 0;
  }

  get itemsAreTruncated() {
    return this.items.length < this.args.total;
  }

  userProfilePath(user) {
    return userPath(user.username);
  }

  solvedByUsers(item) {
    return item.solved_by_users || (item.solved_by ? [item.solved_by] : []);
  }

  @action
  async load() {
    if (this.items || this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.hasError = false;

    const data = {
      start_date: this.date,
      end_date: this.date,
      limit: SUMMARY_LIMIT,
    };

    if (this.args.reportFilters) {
      data.filters = this.args.reportFilters;
    }

    try {
      const response = await ajax("/admin/reports/accepted_solutions", {
        data,
      });
      this.items = response.report.related_items?.solved_topics || [];
    } catch {
      this.hasError = true;
      this.items = null;
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <DMenu
      @ariaLabel={{this.triggerLabel}}
      @contentClass="admin-report-table-summary__content solved-admin-report-table-summary__content"
      @fallbackPlacements={{array "top-start"}}
      @hoverGracePeriod={{200}}
      @identifier="admin-report-table-summary"
      @interactive={{true}}
      @maxWidth={{360}}
      @modalForMobile={{true}}
      @onShow={{this.load}}
      @placement="bottom-start"
      @triggerComponent={{dElement "button"}}
      @triggerClass="admin-report-table-summary"
      @triggers={{array "delayed-hover" "click"}}
      @untriggers={{array "hover" "click"}}
    >
      <:trigger>{{trustHTML @formattedValue}}</:trigger>
      <:content>
        <div class="admin-report-table-summary__body">
          <h3 class="admin-report-table-summary__heading">{{this.title}}</h3>

          {{#if this.isLoading}}
            <p class="admin-report-table-summary__message">
              {{i18n "admin.reports.related_items.table_summary.loading"}}
            </p>
          {{else if this.hasItems}}
            {{#if this.itemsAreTruncated}}
              <p class="admin-report-table-summary__limit">
                {{i18n
                  "admin.reports.related_items.showing"
                  shown=this.items.length
                  total=@total
                }}
              </p>
            {{/if}}
            <ul
              class="admin-report-table-summary__list solved-admin-report-table-summary__list"
            >
              {{#each this.items as |item|}}
                <li class="admin-report-table-summary__item">
                  <a
                    class="solved-admin-report-table-summary__topic-link"
                    href={{item.topic.url}}
                  >
                    {{item.topic.title}}
                  </a>
                  <div class="solved-admin-report-table-summary__topic-meta">
                    {{#each (this.solvedByUsers item) as |user|}}
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
                    {{#if item.category}}
                      {{dCategoryBadge item.category}}
                    {{/if}}
                  </div>
                </li>
              {{/each}}
            </ul>
          {{else if this.hasError}}
            <p class="admin-report-table-summary__message">
              {{i18n "admin.reports.related_items.table_summary.error"}}
            </p>
          {{else}}
            <p class="admin-report-table-summary__message">
              {{i18n "admin.reports.related_items.table_summary.empty"}}
            </p>
          {{/if}}
        </div>
      </:content>
    </DMenu>
  </template>
}
