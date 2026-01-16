import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DecoratedHtml from "discourse/components/decorated-html";
import EditNavigationMenuModal from "discourse/components/sidebar/edit-navigation-menu/modal";
import borderColor from "discourse/helpers/border-color";
import categoryBadge from "discourse/helpers/category-badge";
import concatClass from "discourse/helpers/concat-class";
import dirSpan from "discourse/helpers/dir-span";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { serializedAction, splitWhere } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import { gt, has } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class SidebarEditNavigationMenuCategoriesModal extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked initialLoad = true;
  @tracked filtered = false;
  @tracked fetchedCategoriesGroupings = [];
  @tracked loadingMore = false;
  @tracked
  selectedCategoryIds = new TrackedSet([
    ...this.currentUser.sidebar_category_ids,
  ]);
  selectedFilter = "";
  selectedMode = "everything";
  fetchedCategories;
  loadedFilter;
  loadedMode;
  loadedPage;
  saving = false;
  loadAnotherPage = false;
  unseenCategoryIdsChanged = false;
  observer = new IntersectionObserver(
    ([entry]) => {
      if (entry.isIntersecting) {
        this.observer.disconnect();
        this.loadMore();
      }
    },
    {
      threshold: 1.0,
    }
  );

  constructor() {
    super(...arguments);
    this.performSearch();
  }

  recomputeGroupings() {
    this.fetchedCategoriesGroupings = splitWhere(
      this.fetchedCategories,
      (category) => category.parent_category_id === undefined
    );
  }

  setFetchedCategories(categories) {
    this.fetchedCategories = categories;
    this.recomputeGroupings();
  }

  concatFetchedCategories(categories) {
    this.fetchedCategories = this.fetchedCategories.concat(categories);
    this.recomputeGroupings();
  }

  @action
  didInsert(element) {
    const categoryId = parseInt(element.dataset.categoryId, 10);
    const lastCategoryId = this.fetchedCategories.at(-1)?.id;

    if (categoryId === lastCategoryId) {
      this.observer.disconnect();
      this.observer.observe(element);
    }
  }

  searchOpts() {
    const requestedMode = this.selectedMode;
    const requestedCategoryIds = [...this.selectedCategoryIds];
    const opts = { includeUncategorized: false };

    if (requestedMode === "only-selected") {
      opts.only = requestedCategoryIds;
    } else if (requestedMode === "only-unselected") {
      opts.except = requestedCategoryIds;
    }

    return opts;
  }

  @serializedAction
  async performSearch() {
    this.filtered = false;

    const requestedFilter = this.selectedFilter;
    const requestedMode = this.selectedMode;
    const selectedCategoriesNeedsUpdate =
      this.unseenCategoryIdsChanged && requestedMode !== "everything";

    // Is the current set of displayed categories up-to-date?
    if (
      requestedFilter === this.loadedFilter &&
      requestedMode === this.loadedMode &&
      !selectedCategoriesNeedsUpdate
    ) {
      // The shown categories are up-to-date, so we can do elaboration
      if (this.loadAnotherPage && !this.lastPage) {
        this.loadingMore = true;
        const requestedPage = this.loadedPage + 1;
        const opts = { page: requestedPage, ...this.searchOpts() };

        const categories = await Category.asyncHierarchicalSearch(
          requestedFilter,
          opts
        );

        if (categories.length === 0) {
          this.lastPage = true;
        } else {
          this.concatFetchedCategories(categories);
        }

        this.loadAnotherPage = false;
        this.loadedPage = requestedPage;
        this.loadingMore = false;
      }
    } else {
      // The shown categories are stale, refresh everything
      const requestedCategoryIds = [...this.selectedCategoryIds];
      this.unseenCategoryIdsChanged = false;

      this.setFetchedCategories(
        await Category.asyncHierarchicalSearch(
          requestedFilter,
          this.searchOpts()
        )
      );

      this.loadedFilter = requestedFilter;
      this.loadedMode = requestedMode;
      this.loadedCategoryIds = requestedCategoryIds;
      this.loadedPage = 1;
      this.lastPage = false;
      this.initialLoad = false;
      this.loadAnotherPage = false;
      this.filtered = true;
    }
  }

  @action
  async loadMore() {
    this.loadAnotherPage = true;
    this.debouncedSendRequest();
  }

  debouncedSendRequest() {
    discourseDebounce(this, this.performSearch, INPUT_DELAY);
  }

  @action
  resetFilter() {
    this.selectedMode = "everything";
    this.debouncedSendRequest();
  }

  @action
  filterSelected() {
    this.selectedMode = "only-selected";
    this.debouncedSendRequest();
  }

  @action
  filterUnselected() {
    this.selectedMode = "only-unselected";
    this.debouncedSendRequest();
  }

  @action
  onFilterInput(filter) {
    this.selectedFilter = filter.toLowerCase().trim();
    this.loadAnotherPage = false;
    this.lastPage = false;
    this.initialLoad = true;
    this.debouncedSendRequest();
  }

  @action
  deselectAll() {
    this.selectedCategoryIds.clear();
    this.unseenCategoryIdsChanged = true;
    this.debouncedSendRequest();
  }

  @action
  toggleCategory(categoryId) {
    if (this.selectedCategoryIds.has(categoryId)) {
      this.selectedCategoryIds.delete(categoryId);
    } else {
      this.selectedCategoryIds.add(categoryId);
    }
  }

  @action
  resetToDefaults() {
    this.selectedCategoryIds = new TrackedSet(
      this.siteSettings.default_navigation_menu_categories
        .split("|")
        .map((id) => parseInt(id, 10))
    );

    this.unseenCategoryIdsChanged = true;
    this.debouncedSendRequest();
  }

  @action
  async save() {
    this.saving = true;
    const initialSidebarCategoryIds = this.currentUser.sidebar_category_ids;

    this.currentUser.set("sidebar_category_ids", [...this.selectedCategoryIds]);

    try {
      await this.currentUser.save(["sidebar_category_ids"]);
      this.args.closeModal();
    } catch (error) {
      this.currentUser.set("sidebar_category_ids", initialSidebarCategoryIds);
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <EditNavigationMenuModal
      @title="sidebar.categories_form_modal.title"
      @disableSaveButton={{this.saving}}
      @save={{this.save}}
      @showResetDefaultsButton={{gt
        this.siteSettings.default_navigation_menu_categories.length
        0
      }}
      @resetToDefaults={{this.resetToDefaults}}
      @deselectAll={{this.deselectAll}}
      @deselectAllText={{i18n "sidebar.categories_form_modal.subtitle.text"}}
      @inputFilterPlaceholder={{i18n
        "sidebar.categories_form_modal.filter_placeholder"
      }}
      @onFilterInput={{this.onFilterInput}}
      @resetFilter={{this.resetFilter}}
      @filterSelected={{this.filterSelected}}
      @filterUnselected={{this.filterUnselected}}
      @closeModal={{@closeModal}}
      class="sidebar__edit-navigation-menu__categories-modal"
    >
      <ConditionalLoadingSpinner @condition={{this.initialLoad}}>
        <form
          class={{concatClass
            "sidebar-categories-form"
            (if this.filtered "--filtered")
          }}
        >
          {{#each this.fetchedCategoriesGroupings as |categories|}}
            <div
              style={{borderColor (get categories "0.color") "left"}}
              class="sidebar-categories-form__row"
            >
              {{#each categories as |category|}}
                <div
                  {{didInsert this.didInsert}}
                  data-category-id={{category.id}}
                  data-category-level={{category.level}}
                  class="sidebar-categories-form__category-row"
                >
                  <label
                    for={{concat
                      "sidebar-categories-form__input--"
                      category.id
                    }}
                    class="sidebar-categories-form__category-label"
                  >
                    <div class="sidebar-categories-form__category-wrapper">
                      <div class="sidebar-categories-form__category-badge">
                        {{categoryBadge category}}
                      </div>

                      {{#unless category.parentCategory}}
                        <div
                          class="sidebar-categories-form__category-description"
                        >
                          <DecoratedHtml
                            @html={{dirSpan
                              category.description_excerpt
                              htmlSafe="true"
                            }}
                          />
                        </div>
                      {{/unless}}
                    </div>

                    <input
                      {{on "click" (fn this.toggleCategory category.id)}}
                      type="checkbox"
                      checked={{has this.selectedCategoryIds category.id}}
                      id={{concat
                        "sidebar-categories-form__input--"
                        category.id
                      }}
                      class="sidebar-categories-form__input"
                    />
                  </label>
                </div>
              {{/each}}
            </div>
          {{else}}
            <div class="sidebar-categories-form__no-categories">
              {{i18n "sidebar.categories_form_modal.no_categories"}}
            </div>
          {{/each}}
        </form>
      </ConditionalLoadingSpinner>

      <ConditionalLoadingSpinner @condition={{this.loadingMore}} />
    </EditNavigationMenuModal>
  </template>
}
