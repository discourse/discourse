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
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dElement from "discourse/ui-kit/helpers/d-element";
import { i18n } from "discourse-i18n";

const SUMMARY_LIMIT = 5;

export default class AdminReportTableSummary extends Component {
  @tracked items = null;
  @tracked total = null;
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
      count: this.args.formattedValue,
      date: this.dateLabel,
    });
  }

  get title() {
    return i18n(
      this.args.titleKey ||
        "admin.reports.related_items.table_summary.users_title",
      { date: this.dateLabel }
    );
  }

  get hasItems() {
    return this.items?.length > 0;
  }

  get itemsAreTruncated() {
    return this.items.length < this.total;
  }

  get itemsKey() {
    return this.args.itemsKey || "users";
  }

  userProfilePath(user) {
    return userPath(user.username);
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
      facets: ["related_items"],
      include_related_items: true,
    };

    if (this.args.reportFilters) {
      data.filters = this.args.reportFilters;
    }

    try {
      const response = await ajax(`/admin/reports/${this.args.reportType}`, {
        data,
      });
      this.items = response.report.related_items?.[this.itemsKey] || [];
      this.total =
        response.report.related_items_totals?.[this.itemsKey] ??
        this.items.length;
    } catch {
      this.hasError = true;
      this.items = null;
      this.total = null;
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <DMenu
      @ariaLabel={{this.triggerLabel}}
      @contentClass="admin-report-table-summary__content"
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
      aria-label={{this.triggerLabel}}
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
                  total=this.total
                }}
              </p>
            {{/if}}
            <ul
              class={{dConcatClass
                "admin-report-table-summary__list"
                @listClass
              }}
            >
              {{#each this.items as |item|}}
                <li class="admin-report-table-summary__item">
                  {{#if @itemComponent}}
                    {{component @itemComponent item=item}}
                  {{else}}
                    <a
                      class="admin-report-table-summary__user-link"
                      href={{this.userProfilePath item.user}}
                    >
                      {{dAvatar
                        item.user
                        imageSize="small"
                        extraClasses="admin-report-table-summary__avatar"
                      }}
                      <span class="admin-report-table-summary__user-identity">
                        <span class="admin-report-table-summary__username">
                          {{formatUsername item.user.username}}
                        </span>
                        {{#if item.user.name}}
                          <span class="admin-report-table-summary__name">
                            {{item.user.name}}
                          </span>
                        {{/if}}
                      </span>
                    </a>
                  {{/if}}
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
