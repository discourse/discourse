import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import { i18n } from "discourse-i18n";

const ROW_ORDER = ["new_members", "returning", "staff"];
const MAX_CATEGORIES = 10;

export default class WhosPosting extends Component {
  @service currentUser;
  @service toasts;

  @tracked selectedCategories = [];
  @tracked overridePosters = null;
  @tracked loading = false;

  constructor() {
    super(...arguments);

    this.selectedCategories = (this.args.posters?.category_ids ?? [])
      .map((id) => Category.findById(id))
      .filter(Boolean);
  }

  get reportQuery() {
    const query = {};
    const ids = this.selectedCategories.map((c) => c.id);
    if (ids.length > 0) {
      query.filters = { category_ids: ids.join(",") };
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
  onCategoriesChange(categories) {
    this.selectedCategories = categories;
    this.refetch();
    this.#persistSelection();
  }

  #persistSelection() {
    if (!this.currentUser?.admin) {
      return;
    }

    ajax("/admin/dashboard/sections/engagement/settings/whos_posting.json", {
      type: "PUT",
      contentType: "application/json",
      data: JSON.stringify({
        category_ids: this.selectedCategories.map((c) => c.id),
      }),
    }).catch(() => {
      this.toasts.error({
        duration: "short",
        data: {
          message: i18n(
            "admin.dashboard.sections.engagement.whos_posting.save_error"
          ),
        },
      });
    });
  }

  @action
  onPeriodChange() {
    if (this.selectedCategories.length === 0) {
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
    const ids = this.selectedCategories.map((c) => c.id);
    if (ids.length > 0) {
      data.filters = { category_ids: ids.join(",") };
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
          <CategorySelector
            @categories={{this.selectedCategories}}
            @onChange={{this.onCategoriesChange}}
            @options={{hash maximum=MAX_CATEGORIES none="category.all"}}
          />
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
