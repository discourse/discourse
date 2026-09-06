import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import CompareGroups from "discourse/admin/components/modal/compare-groups";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import MultipleCategoriesSelector from "discourse/select-kit/components/multiple-categories-selector";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const MAX_CATEGORIES = 10;
const DEFAULT_GROUPS = ["new_members", "returning", "staff"];
const GROUP_SEGMENT_CLASSES = [
  "--group-0",
  "--group-1",
  "--group-2",
  "--group-3",
  "--group-4",
  "--group-5",
];

function sameGroups(a, b) {
  return a.length === b.length && a.every((token, index) => token === b[index]);
}

export default class WhosPosting extends Component {
  @service currentUser;
  @service toasts;
  @service modal;

  @tracked selectedCategories = [];
  @tracked selectedGroups = [];
  @tracked overridePosters = null;
  @tracked loading = false;

  constructor() {
    super(...arguments);

    this.selectedCategories = (this.args.posters?.category_ids ?? [])
      .map((id) => Category.findById(id))
      .filter(Boolean);
    this.appliedCategoryIds = this.selectedCategories.map((c) => c.id);
    this.selectedGroups = this.args.posters?.groups ?? DEFAULT_GROUPS;
  }

  get reportQuery() {
    const query = {};
    const filters = {};
    const ids = this.selectedCategories.map((c) => c.id);
    if (ids.length > 0) {
      filters.category_ids = ids.join(",");
    }
    if (!sameGroups(this.selectedGroups, DEFAULT_GROUPS)) {
      filters.groups = this.selectedGroups.join(",");
    }
    if (Object.keys(filters).length > 0) {
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
    let groupIndex = 0;
    return rows.map((row) => {
      const segmentClass =
        row.kind === "group"
          ? GROUP_SEGMENT_CLASSES[groupIndex++ % GROUP_SEGMENT_CLASSES.length]
          : `--${row.type.replace("_", "-")}`;
      return {
        type: row.type,
        label: row.name,
        share: row.share,
        shareFormatted: `${Math.round(row.share)}%`,
        segmentStyle: trustHTML(`width: ${row.share}%`),
        segmentClass,
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
  }

  @action
  onCategoriesClose() {
    const ids = this.selectedCategories.map((c) => c.id);
    const unchanged =
      ids.length === this.appliedCategoryIds.length &&
      ids.every((id) => this.appliedCategoryIds.includes(id));

    // apply and save once the picker closes, not on every individual pick
    if (unchanged) {
      return;
    }

    this.appliedCategoryIds = ids;
    this.refetch();
    this.#persist();
  }

  @action
  openCompareGroups() {
    this.modal.show(CompareGroups, {
      model: {
        currentTokens: this.selectedGroups,
        footerNote: i18n(
          "admin.dashboard.sections.engagement.whos_posting.modal.footer_note"
        ),
        onApply: (tokens) => {
          this.selectedGroups = tokens;
          this.refetch();
          this.#persist();
        },
      },
    });
  }

  #persist() {
    if (!this.currentUser?.admin) {
      return;
    }

    ajax("/admin/dashboard/sections/engagement/settings/whos_posting.json", {
      type: "PUT",
      contentType: "application/json",
      data: JSON.stringify({
        category_ids: this.selectedCategories.map((c) => c.id),
        groups: this.selectedGroups,
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
    const hasCustomSelection =
      this.selectedCategories.length > 0 ||
      !sameGroups(this.selectedGroups, DEFAULT_GROUPS);

    if (!hasCustomSelection) {
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
    const filters = { groups: this.selectedGroups.join(",") };
    const ids = this.selectedCategories.map((c) => c.id);
    if (ids.length > 0) {
      filters.category_ids = ids.join(",");
    }
    data.filters = filters;

    try {
      const response = await ajax(
        "/admin/reports/posters_by_member_type.json",
        { data }
      );
      const report = response?.report;
      const rows = report?.data ?? [];
      this.overridePosters = {
        rows,
        total: report?.total ?? 0,
        category_ids: this.args.posters?.category_ids,
        groups: this.selectedGroups,
      };
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
          <MultipleCategoriesSelector
            @categories={{this.selectedCategories}}
            @onChange={{this.onCategoriesChange}}
            @onClose={{this.onCategoriesClose}}
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

      <DButton
        @action={{this.openCompareGroups}}
        @icon="plus"
        @label="admin.dashboard.sections.engagement.whos_posting.add_group"
        class="btn-transparent db-whos-posting__add-group"
      />
    </div>
  </template>
}
