import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import { i18n } from "discourse-i18n";

const ROW_ORDER = ["new_members", "returning", "staff"];

export default class WhosPosting extends Component {
  @tracked categoryId = null;
  @tracked includeSubcategories = false;
  @tracked overridePosters = null;
  @tracked loading = false;

  get hasSubcategories() {
    if (!this.categoryId) {
      return false;
    }
    const category = Category.findById(this.categoryId);
    return (category?.subcategories?.length ?? 0) > 0;
  }

  get #categoryFilters() {
    if (!this.categoryId) {
      return null;
    }
    const filters = { category: this.categoryId };
    if (this.includeSubcategories) {
      filters.include_subcategories = true;
    }
    return filters;
  }

  get reportQuery() {
    const query = {};
    const filters = this.#categoryFilters;
    if (filters) {
      query.filters = filters;
    }
    if (this.args.startDate) {
      query.start_date = this.args.startDate.toISOString().slice(0, 10);
    }
    if (this.args.endDate) {
      query.end_date = this.args.endDate.toISOString().slice(0, 10);
    }
    return query;
  }

  get posters() {
    return this.overridePosters ?? this.args.posters;
  }

  get rows() {
    const rows = this.posters?.rows ?? [];
    const byType = Object.fromEntries(rows.map((r) => [r.type, r]));
    return ROW_ORDER.map((type) => {
      const row = byType[type] ?? { type, count: 0, share: 0 };
      return {
        type,
        label: i18n(`admin.dashboard.sections.engagement.whos_posting.${type}`),
        share: row.share,
        shareFormatted: `${Math.round(row.share)}%`,
        segmentStyle: trustHTML(`width: ${row.share}%`),
        segmentClass: `--${type.replace("_", "-")}`,
      };
    });
  }

  get totalPosts() {
    return this.posters?.total ?? 0;
  }

  get hasData() {
    return this.totalPosts > 0;
  }

  get ariaLabel() {
    const parts = this.rows.map((r) => `${r.label} ${r.shareFormatted}`);
    return parts.join(", ");
  }

  @action
  onCategoryChange(categoryId) {
    this.categoryId = categoryId;
    if (!categoryId) {
      this.includeSubcategories = false;
    }
    this.refetch();
  }

  @action
  onSubcategoriesToggle(event) {
    this.includeSubcategories = event.target.checked;
    this.refetch();
  }

  @action
  onPeriodChange() {
    if (!this.categoryId) {
      this.overridePosters = null;
    } else {
      this.refetch();
    }
  }

  async refetch() {
    this.loading = true;

    const data = {
      start_date: this.args.startDate?.toISOString().slice(0, 10),
      end_date: this.args.endDate?.toISOString().slice(0, 10),
    };
    const filters = this.#categoryFilters;
    if (filters) {
      data.filters = filters;
    }

    try {
      const response = await ajax(
        "/admin/reports/posters_by_member_type.json",
        { data }
      );
      const report = response?.report;
      const rows = report?.data ?? [];
      this.overridePosters = { rows, total: report?.total ?? 0 };
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <div
      class="db-whos-posting"
      {{didUpdate this.onPeriodChange @startDate @endDate}}
    >
      <div class="db-section__row-block-header">
        <LinkTo
          @route="adminReports.show"
          @model="posters_by_member_type"
          @query={{this.reportQuery}}
          class="db-section__row-block-title --label"
        >
          {{i18n "admin.dashboard.sections.engagement.whos_posting.title"}}
        </LinkTo>
        <div class="db-whos-posting__filter">
          <CategoryChooser
            @value={{this.categoryId}}
            @onChange={{this.onCategoryChange}}
            @options={{hash none="category.all" autoInsertNoneItem=true}}
          />
          {{#if this.hasSubcategories}}
            <label class="db-whos-posting__subcategories">
              <input
                type="checkbox"
                checked={{this.includeSubcategories}}
                {{on "change" this.onSubcategoriesToggle}}
              />
              {{i18n
                "admin.dashboard.sections.engagement.whos_posting.include_subcategories"
              }}
            </label>
          {{/if}}
        </div>
      </div>

      {{#if this.hasData}}
        <div
          class="db-whos-posting__bars"
          role="img"
          aria-label={{this.ariaLabel}}
        >
          {{#each this.rows as |row|}}
            <div class="db-whos-posting__bar-row">
              <span class="db-whos-posting__bar-label">{{row.label}}</span>
              <span class="db-whos-posting__bar-track">
                <span
                  class="db-whos-posting__bar-fill {{row.segmentClass}}"
                  style={{row.segmentStyle}}
                ></span>
              </span>
              <span
                class="db-whos-posting__bar-share"
              >{{row.shareFormatted}}</span>
            </div>
          {{/each}}
        </div>
      {{else}}
        <p class="db-whos-posting__empty">
          {{i18n "admin.dashboard.sections.engagement.whos_posting.empty"}}
        </p>
      {{/if}}
    </div>
  </template>
}
