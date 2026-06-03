import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { number } from "discourse/lib/formatter";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import { eq } from "discourse/truth-helpers";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import I18n, { i18n } from "discourse-i18n";

export default class ActivityByCategory extends Component {
  @tracked selectedCategories = [];
  @tracked overrideActivity = null;
  @tracked loading = false;
  @tracked sortBy = "share";
  @tracked sortDir = "desc";

  constructor() {
    super(...arguments);

    this.selectedCategories = (this.args.activity?.rows ?? [])
      .map((row) => Category.findById(row.category_id))
      .filter(Boolean);
  }

  get activity() {
    return this.overrideActivity ?? this.args.activity;
  }

  get rows() {
    const rows = this.activity?.rows ?? [];
    const decorated = rows.map((row) => ({
      ...row,
      category: Category.findById(row.category_id),
      topicsFormatted: I18n.toNumber(row.topics, { precision: 0 }),
      postsFormatted: I18n.toNumber(row.posts, { precision: 0 }),
      pageViewsFormatted: number(row.page_views),
      changeClass:
        row.share_change > 0 ? "--pos" : row.share_change < 0 ? "--neg" : "",
      swatchStyle: trustHTML(`background-color: #${this.#safeHex(row.color)}`),
    }));

    const direction = this.sortDir === "asc" ? 1 : -1;
    return decorated.sort((a, b) => {
      const av = a[this.sortBy] ?? 0;
      const bv = b[this.sortBy] ?? 0;
      return av === bv ? 0 : av > bv ? direction : -direction;
    });
  }

  get hasData() {
    return (this.activity?.rows ?? []).length > 0;
  }

  get shareSortIndicator() {
    return this.sortDir === "desc" ? "↓" : "↑";
  }

  #safeHex(color) {
    return /^[0-9a-fA-F]{6}$/.test(color) ? color : "cccccc";
  }

  @action
  onCategoriesChange(categories) {
    this.selectedCategories = categories;
    this.refetch();
  }

  @action
  onPeriodChange() {
    if (this.selectedCategories.length === 0) {
      this.overrideActivity = null;
    } else {
      this.refetch();
    }
  }

  @action
  toggleShareSort() {
    if (this.sortBy === "share") {
      this.sortDir = this.sortDir === "desc" ? "asc" : "desc";
    } else {
      this.sortBy = "share";
      this.sortDir = "desc";
    }
  }

  async refetch() {
    this.loading = true;

    const data = {
      start_date: this.args.startDate?.toISOString().slice(0, 10),
      end_date: this.args.endDate?.toISOString().slice(0, 10),
    };
    const ids = this.selectedCategories.map((c) => c.id);
    if (ids.length > 0) {
      data.filters = { category_ids: ids.join(",") };
    }

    try {
      const response = await ajax("/admin/reports/activity_by_category.json", {
        data,
      });
      const report = response?.report;
      this.overrideActivity = {
        rows: report?.data ?? [],
        total: report?.total ?? 0,
      };
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <div
      class="db-activity"
      {{didUpdate this.onPeriodChange @startDate @endDate}}
    >
      <div class="db-activity__header">
        <LinkTo
          @route="adminReports.show"
          @model="activity_by_category"
          class="db-section__row-block-title"
        >
          {{i18n
            "admin.dashboard.sections.engagement.activity_by_category.title"
          }}
        </LinkTo>
        <CategorySelector
          @categories={{this.selectedCategories}}
          @onChange={{this.onCategoriesChange}}
        />
      </div>

      <p class="db-activity__description">
        {{i18n
          "admin.dashboard.sections.engagement.activity_by_category.description"
        }}
      </p>

      {{#if this.hasData}}
        <table class="db-activity-table">
          <thead>
            <tr>
              <th class="db-activity-table__col-category">
                {{i18n
                  "admin.dashboard.sections.engagement.activity_by_category.category"
                }}
              </th>
              <th class="db-activity-table__col-number">
                {{i18n
                  "admin.dashboard.sections.engagement.activity_by_category.topics"
                }}
              </th>
              <th class="db-activity-table__col-number">
                {{i18n
                  "admin.dashboard.sections.engagement.activity_by_category.posts"
                }}
              </th>
              <th class="db-activity-table__col-number">
                {{i18n
                  "admin.dashboard.sections.engagement.activity_by_category.page_views"
                }}
              </th>
              <th class="db-activity-table__col-number">
                <button
                  type="button"
                  class="db-activity-table__sort-button"
                  {{on "click" this.toggleShareSort}}
                >
                  {{i18n
                    "admin.dashboard.sections.engagement.activity_by_category.share"
                  }}
                  {{#if (eq this.sortBy "share")}}
                    <span aria-hidden="true">{{this.shareSortIndicator}}</span>
                  {{/if}}
                </button>
              </th>
              <th class="db-activity-table__col-number">
                {{i18n
                  "admin.dashboard.sections.engagement.activity_by_category.vs_prior"
                }}
              </th>
            </tr>
          </thead>
          <tbody>
            {{#each this.rows as |row|}}
              <tr>
                <td class="db-activity-table__cell-category">
                  {{#if row.category}}
                    {{dCategoryBadge row.category}}
                  {{else}}
                    <span
                      class="db-activity-table__swatch"
                      style={{row.swatchStyle}}
                      aria-hidden="true"
                    ></span>
                    {{row.name}}
                  {{/if}}
                </td>
                <td
                  class="db-activity-table__cell-number"
                >{{row.topicsFormatted}}</td>
                <td
                  class="db-activity-table__cell-number"
                >{{row.postsFormatted}}</td>
                <td
                  class="db-activity-table__cell-number"
                >{{row.pageViewsFormatted}}</td>
                <td
                  class="db-activity-table__cell-number"
                >{{row.share_formatted}}</td>
                <td
                  class="db-activity-table__cell-number db-delta
                    {{row.changeClass}}"
                >{{row.share_change_formatted}}</td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <p class="db-activity__empty">
          {{i18n
            "admin.dashboard.sections.engagement.activity_by_category.empty"
          }}
        </p>
      {{/if}}
    </div>
  </template>
}
