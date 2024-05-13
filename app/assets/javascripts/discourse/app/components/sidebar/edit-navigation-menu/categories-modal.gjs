import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";
import { gt, has, includes, not } from "truth-helpers";
import EditNavigationMenuModal from "discourse/components/sidebar/edit-navigation-menu/modal";
import borderColor from "discourse/helpers/border-color";
import categoryBadge from "discourse/helpers/category-badge";
import dirSpan from "discourse/helpers/dir-span";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import { INPUT_DELAY } from "discourse-common/config/environment";
import i18n from "discourse-common/helpers/i18n";
import discourseDebounce from "discourse-common/lib/debounce";

// Given a list, break into chunks starting a new chunk whenever the predicate
// is true for an element.
function splitWhere(elements, f) {
  return elements.reduce((acc, el, i) => {
    if (i === 0 || f(el)) {
      acc.push([]);
    }
    acc[acc.length - 1].push(el);
    return acc;
  }, []);
}

function findAncestors(categories) {
  let categoriesToCheck = categories;
  const ancestors = [];

  for (let i = 0; i < 3; i++) {
    categoriesToCheck = categoriesToCheck
      .map((c) => Category.findById(c.parent_category_id))
      .filter(Boolean)
      .uniqBy((c) => c.id);

    ancestors.push(...categoriesToCheck);
  }

  return ancestors;
}

export default class SidebarEditNavigationMenuCategoriesModal extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked initialLoad = true;
  @tracked filteredCategoriesGroupings = [];
  @tracked filteredCategoryIds = [];
  @tracked
  selectedSidebarCategoryIds = new TrackedSet([
    ...this.currentUser.sidebar_category_ids,
  ]);
  hasMorePages;
  loadedFilter;
  loadedMode;
  loadedPage;
  processing = false;
  requestedFilter;
  requestedMode;
  saving = false;
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
    this.setFilterAndMode("", "everything");
  }

  setFilteredCategories(categories) {
    this.filteredCategories = categories;
    const ancestors = findAncestors(categories);
    const allCategories = categories.concat(ancestors).uniqBy((c) => c.id);

    this.filteredCategoriesGroupings = splitWhere(
      Category.sortCategories(allCategories),
      (category) => category.parent_category_id === undefined
    );

    this.filteredCategoryIds = categories.map((c) => c.id);
  }

  concatFilteredCategories(categories) {
    this.setFilteredCategories(this.filteredCategories.concat(categories));
  }

  setFetchedCategories(mode, categories) {
    this.setFilteredCategories(this.applyMode(mode, categories));
  }

  concatFetchedCategories(mode, categories) {
    this.concatFilteredCategories(this.applyMode(mode, categories));
  }

  applyMode(mode, categories) {
    return categories.filter((c) => {
      switch (mode) {
        case "everything":
          return true;
        case "only-selected":
          return this.selectedSidebarCategoryIds.has(c.id);
        case "only-unselected":
          return !this.selectedSidebarCategoryIds.has(c.id);
      }
    });
  }

  @action
  didInsert(element) {
    this.observer.disconnect();
    this.observer.observe(element);
  }

  async searchCategories(filter, mode) {
    if (filter === "" && mode === "only-selected") {
      this.setFilteredCategories(
        await Category.asyncFindByIds([...this.selectedSidebarCategoryIds])
      );

      this.loadedPage = null;
      this.hasMorePages = false;
    } else {
      const { categories } = await Category.asyncSearch(filter, {
        includeAncestors: true,
        includeUncategorized: false,
      });

      this.setFetchedCategories(mode, categories);

      this.loadedPage = 1;
      this.hasMorePages = true;
    }
  }

  async setFilterAndMode(newFilter, newMode) {
    this.requestedFilter = newFilter;
    this.requestedMode = newMode;

    if (!this.processing) {
      this.processing = true;

      try {
        while (
          this.loadedFilter !== this.requestedFilter ||
          this.loadedMode !== this.requestedMode
        ) {
          const filter = this.requestedFilter;
          const mode = this.requestedMode;

          await this.searchCategories(filter, mode);

          this.loadedFilter = filter;
          this.loadedMode = mode;
          this.initialLoad = false;
        }
      } finally {
        this.processing = false;
      }
    }
  }

  async loadMore() {
    if (!this.processing && this.hasMorePages) {
      this.processing = true;

      try {
        const page = this.loadedPage + 1;
        const { categories } = await Category.asyncSearch(
          this.requestedFilter,
          {
            includeAncestors: true,
            includeUncategorized: false,
            page,
          }
        );
        this.loadedPage = page;

        if (categories.length === 0) {
          this.hasMorePages = false;
        } else {
          this.concatFetchedCategories(this.requestedMode, categories);
        }
      } finally {
        this.processing = false;
      }

      if (
        this.loadedFilter !== this.requestedFilter ||
        this.loadedMode !== this.requestedMode
      ) {
        await this.setFilterAndMode(this.requestedFilter, this.requestedMode);
      }
    }
  }

  debouncedSetFilterAndMode(filter, mode) {
    discourseDebounce(this, this.setFilterAndMode, filter, mode, INPUT_DELAY);
  }

  @action
  resetFilter() {
    this.debouncedSetFilterAndMode(this.requestedFilter, "everything");
  }

  @action
  filterSelected() {
    this.debouncedSetFilterAndMode(this.requestedFilter, "only-selected");
  }

  @action
  filterUnselected() {
    this.debouncedSetFilterAndMode(this.requestedFilter, "only-unselected");
  }

  @action
  onFilterInput(filter) {
    this.debouncedSetFilterAndMode(
      filter.toLowerCase().trim(),
      this.requestedMode
    );
  }

  @action
  deselectAll() {
    this.selectedSidebarCategoryIds.clear();
  }

  @action
  toggleCategory(categoryId) {
    if (this.selectedSidebarCategoryIds.has(categoryId)) {
      this.selectedSidebarCategoryIds.delete(categoryId);
    } else {
      this.selectedSidebarCategoryIds.add(categoryId);
    }
  }

  @action
  resetToDefaults() {
    this.selectedSidebarCategoryIds = new TrackedSet(
      this.siteSettings.default_navigation_menu_categories
        .split("|")
        .map((id) => parseInt(id, 10))
    );
  }

  @action
  async save() {
    this.saving = true;
    const initialSidebarCategoryIds = this.currentUser.sidebar_category_ids;

    this.currentUser.set("sidebar_category_ids", [
      ...this.selectedSidebarCategoryIds,
    ]);

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
      <form class="sidebar-categories-form">
        {{#if this.initialLoad}}
          <div class="sidebar-categories-form__loading">
            {{loadingSpinner size="small"}}
          </div>
        {{else}}
          {{#each this.filteredCategoriesGroupings as |categories|}}
            <div
              {{didInsert this.didInsert}}
              style={{borderColor (get categories "0.color") "left"}}
              class="sidebar-categories-form__row"
            >
              {{#each categories as |category|}}
                <div
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
                          {{dirSpan
                            category.description_excerpt
                            htmlSafe="true"
                          }}
                        </div>
                      {{/unless}}
                    </div>

                    <input
                      {{on "click" (fn this.toggleCategory category.id)}}
                      type="checkbox"
                      checked={{has
                        this.selectedSidebarCategoryIds
                        category.id
                      }}
                      disabled={{not
                        (includes this.filteredCategoryIds category.id)
                      }}
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
        {{/if}}
      </form>
    </EditNavigationMenuModal>
  </template>
}
