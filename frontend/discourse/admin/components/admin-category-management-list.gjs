import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import AdminFilterControls from "discourse/admin/components/admin-filter-controls";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { availableCategoryType } from "discourse/lib/category-type-utils";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const PAGE_SIZE = 50;
const DESCRIPTION_MAX_LENGTH = 500;
const VISIBILITY_FILTER_OPTIONS = [
  {
    value: "all",
    label: i18n("admin.config.category_management.visibility_filter.all"),
  },
  {
    value: "public",
    label: i18n("admin.config.category_management.visibility_filter.public"),
  },
  {
    value: "restricted",
    label: i18n(
      "admin.config.category_management.visibility_filter.restricted"
    ),
  },
];

export default class AdminCategoryManagementList extends Component {
  @tracked categories = [];
  @tracked loading = true;
  @tracked loadingMore = false;
  @tracked filter;
  @tracked visibilityFilter;

  page = 0;
  hasMore = false;

  constructor() {
    super(...arguments);
    this.load();
  }

  get titleLabel() {
    return `admin.config.category_management.types.${this.args.categoryType.id}.title`;
  }

  get descriptionLabel() {
    return `admin.config.category_management.types.${this.args.categoryType.id}.description`;
  }

  get noResultsMessage() {
    return i18n("admin.config.category_management.no_results", {
      type: i18n(this.titleLabel),
    });
  }

  get showEmptyList() {
    return (
      !this.loading &&
      !this.filter &&
      !this.visibilityFilter &&
      this.categories.length === 0
    );
  }

  get showCategoryTypeBadges() {
    return this.args.categoryType.id === "all";
  }

  @action
  typeChanged() {
    this.categories = [];
    this.loading = true;
    this.loadingMore = false;
    this.filter = null;
    this.visibilityFilter = null;
    this.page = 0;
    this.hasMore = false;
    this.load();
  }

  @action
  onTextFilterChange(event) {
    this.loading = true;
    this.filter = event.target.value;
    this.page = 0;
    discourseDebounce(this, this.load, INPUT_DELAY);
  }

  @action
  onVisibilityFilterChange(value) {
    this.loading = true;
    this.visibilityFilter = value === "all" ? null : value;
    this.page = 0;
    this.load();
  }

  @action
  onResetFilters() {
    this.loading = true;
    this.filter = null;
    this.visibilityFilter = null;
    this.page = 0;
    this.load();
  }

  @action
  async load({ append = false } = {}) {
    try {
      const data = await ajax("/admin/config/category-management/categories", {
        data: {
          type: this.args.categoryType.id,
          filter: this.filter,
          visibility: this.visibilityFilter,
          page: this.page,
          per_page: PAGE_SIZE,
        },
      });

      if (append) {
        this.categories = [...this.categories, ...data.categories];
      } else {
        this.categories = data.categories;
      }

      this.hasMore = data.has_more;
    } finally {
      this.loading = false;
    }
  }

  @action
  async loadMore() {
    if (this.loadingMore || !this.hasMore) {
      return;
    }

    this.page += 1;
    this.loadingMore = true;

    try {
      await this.load({ append: true });
    } finally {
      this.loadingMore = false;
    }
  }

  truncatedDescription(category) {
    const description = category.description_text || "";

    if (description.length <= DESCRIPTION_MAX_LENGTH) {
      return description;
    }

    return `${description.slice(0, DESCRIPTION_MAX_LENGTH - 3).trimEnd()}...`;
  }

  <template>
    <div
      class="admin-category-management-list admin-detail"
      {{didUpdate this.typeChanged @categoryType}}
    >
      <DPageSubheader
        @titleLabel={{i18n this.titleLabel}}
        @descriptionLabel={{i18n this.descriptionLabel}}
      />

      <PluginOutlet
        @name="admin-category-management-type-tab"
        @outletArgs={{lazyHash
          categoryType=@categoryType
          categories=this.categories
        }}
      />

      {{#unless (availableCategoryType @categoryType)}}
        <PluginOutlet
          @name="admin-category-management-type-unavailable"
          @outletArgs={{lazyHash type=@categoryType}}
        >
          <div class="admin-category-management-list__unavailable">
            {{i18n
              "admin.config.category_management.types.unavailable"
              categoryType=@categoryType.name
            }}
          </div>
        </PluginOutlet>
      {{/unless}}

      {{#if (availableCategoryType @categoryType)}}
        <AdminFilterControls
          @array={{this.categories}}
          @dropdownOptions={{VISIBILITY_FILTER_OPTIONS}}
          @inputPlaceholder={{i18n
            "admin.config.category_management.filter_placeholder"
          }}
          @noResultsMessage={{this.noResultsMessage}}
          @onTextFilterChange={{this.onTextFilterChange}}
          @onDropdownFilterChange={{this.onVisibilityFilterChange}}
          @onResetFilters={{this.onResetFilters}}
          @loading={{this.loading}}
        >
          <:aboveContent>
            <DConditionalLoadingSpinner @condition={{this.loading}} />

            {{#if this.showEmptyList}}
              <p class="admin-category-management-list__empty">
                {{this.noResultsMessage}}
              </p>
            {{/if}}
          </:aboveContent>

          <:content as |categories|>
            {{#if categories.length}}
              <DLoadMore
                @action={{this.loadMore}}
                @enabled={{this.hasMore}}
                @isLoading={{this.loadingMore}}
                @rootMargin="0px 0px 250px 0px"
              >
                <table class="d-table admin-category-management-list__table">
                  <colgroup>
                    <col
                      class="admin-category-management-list__overview-column"
                    />
                    <col
                      class="admin-category-management-list__visibility-column"
                    />
                    <col
                      class="admin-category-management-list__topics-column"
                    />
                    <col
                      class="admin-category-management-list__controls-column"
                    />
                  </colgroup>
                  <thead class="d-table__header">
                    <tr class="d-table__row">
                      <th class="d-table__header-cell">{{i18n
                          "admin.config.category_management.table.category"
                        }}</th>
                      <th class="d-table__header-cell">{{i18n
                          "admin.config.category_management.table.visibility"
                        }}</th>
                      <th class="d-table__header-cell">{{i18n
                          "admin.config.category_management.table.topics"
                        }}</th>
                      <th class="d-table__header-cell"></th>
                    </tr>
                  </thead>
                  <tbody class="d-table__body">
                    {{#each categories as |category|}}
                      <tr class="d-table__row" data-category-id={{category.id}}>
                        <td
                          class="d-table__cell --overview admin-category-management-list__category"
                        >
                          <div
                            class="admin-category-management-list__category-badges"
                          >
                            {{#each category.badge_chain as |badge index|}}
                              {{#if index}}
                                <span
                                  class="admin-category-management-list__category-separator"
                                  aria-hidden="true"
                                >/</span>
                              {{/if}}
                              {{dCategoryBadge
                                badge
                                (hash link=false hideParent=true)
                              }}
                            {{/each}}
                          </div>

                          <div
                            class="d-table__overview-about admin-category-management-list__description"
                          >
                            {{this.truncatedDescription category}}
                          </div>

                          {{#if this.showCategoryTypeBadges}}
                            <div
                              class="d-table__badges admin-category-management-list__type-badges"
                            >
                              {{#each
                                category.category_types
                                as |categoryType|
                              }}
                                <span
                                  class="d-table-badge admin-category-management-list__type-badge"
                                  data-category-type={{categoryType.id}}
                                >
                                  <span class="d-table-badge__content">
                                    {{categoryType.name}}
                                  </span>
                                </span>
                              {{/each}}
                            </div>
                          {{/if}}
                        </td>
                        <td
                          class="d-table__cell --detail admin-category-management-list__visibility-cell"
                        >
                          <div class="d-table__mobile-label">
                            {{i18n
                              "admin.config.category_management.table.visibility"
                            }}
                          </div>

                          <span
                            class="admin-category-management-list__visibility"
                          >
                            {{#if category.read_restricted}}
                              {{dIcon "lock"}}
                              {{i18n
                                "admin.config.category_management.visibility.restricted"
                              }}
                            {{else}}
                              {{i18n
                                "admin.config.category_management.visibility.public"
                              }}
                            {{/if}}
                          </span>
                        </td>
                        <td
                          class="d-table__cell --detail admin-category-management-list__topic-count"
                        >
                          <div class="d-table__mobile-label">
                            {{i18n
                              "admin.config.category_management.table.topics"
                            }}
                          </div>

                          {{category.topic_count}}
                        </td>
                        <td class="d-table__cell --controls">
                          <div class="d-table__cell-actions">
                            <DButton
                              @href={{category.edit_url}}
                              @label="admin.config.category_management.open_settings"
                              class="btn-default btn-small admin-category-management-list__open-settings"
                            />
                          </div>
                        </td>
                      </tr>
                    {{/each}}
                  </tbody>
                </table>
              </DLoadMore>
            {{/if}}
          </:content>
        </AdminFilterControls>
      {{/if}}
    </div>
  </template>
}
