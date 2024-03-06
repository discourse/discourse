import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { gt, includes, not } from "truth-helpers";
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

export default class extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked initialLoad = true;
  @tracked filteredCategoriesGroupings = [];
  @tracked filteredCategoryIds = [];

  @tracked
  selectedSidebarCategoryIds = [...this.currentUser.sidebar_category_ids];

  constructor() {
    super(...arguments);

    this.processing = false;
    this.setFilterAndMode("", "everything");
  }

  setFilteredCategories(categories) {
    const ancestors = findAncestors(categories);
    const allCategories = categories.concat(ancestors).uniqBy((c) => c.id);

    if (this.siteSettings.fixed_category_positions) {
      allCategories.sort((a, b) => a.position - b.position);
    }

    this.filteredCategoriesGroupings = splitWhere(
      Category.sortCategories(allCategories),
      (category) => category.parent_category_id === undefined
    );

    this.filteredCategoryIds = categories.map((c) => c.id);
  }

  async searchCategories(filter, mode) {
    if (filter === "" && mode === "only-selected") {
      this.setFilteredCategories(
        await Category.asyncFindByIds(this.selectedSidebarCategoryIds)
      );
    } else {
      const { categories } = await Category.asyncSearch(filter, {
        includeAncestors: true,
        includeUncategorized: false,
      });

      const filteredFetchedCategories = categories.filter((c) => {
        switch (mode) {
          case "everything":
            return true;
          case "only-selected":
            return this.selectedSidebarCategoryIds.includes(c.id);
          case "only-unselected":
            return !this.selectedSidebarCategoryIds.includes(c.id);
        }
      });

      this.setFilteredCategories(filteredFetchedCategories);
    }
  }

  async setFilterAndMode(newFilter, newMode) {
    this.filter = newFilter;
    this.mode = newMode;

    if (!this.processing) {
      this.processing = true;

      try {
        while (true) {
          const filter = this.filter;
          const mode = this.mode;

          await this.searchCategories(filter, mode);

          this.initialLoad = false;

          if (filter === this.filter && mode === this.mode) {
            break;
          }
        }
      } finally {
        this.processing = false;
      }
    }
  }

  debouncedSetFilterAndMode(filter, mode) {
    discourseDebounce(this, this.setFilterAndMode, filter, mode, INPUT_DELAY);
  }

  @action
  resetFilter() {
    this.debouncedSetFilterAndMode(this.filter, "everything");
  }

  @action
  filterSelected() {
    this.debouncedSetFilterAndMode(this.filter, "only-selected");
  }

  @action
  filterUnselected() {
    this.debouncedSetFilterAndMode(this.filter, "only-unselected");
  }

  @action
  onFilterInput(filter) {
    this.debouncedSetFilterAndMode(filter.toLowerCase().trim(), this.mode);
  }

  @action
  deselectAll() {
    this.selectedSidebarCategoryIds.clear();
  }

  @action
  toggleCategory(categoryId) {
    if (this.selectedSidebarCategoryIds.includes(categoryId)) {
      this.selectedSidebarCategoryIds.removeObject(categoryId);
    } else {
      this.selectedSidebarCategoryIds.addObject(categoryId);
    }
  }

  @action
  resetToDefaults() {
    this.selectedSidebarCategoryIds =
      this.siteSettings.default_navigation_menu_categories
        .split("|")
        .map((id) => parseInt(id, 10));
  }

  @action
  save() {
    this.saving = true;
    const initialSidebarCategoryIds = this.currentUser.sidebar_category_ids;

    this.currentUser.set(
      "sidebar_category_ids",
      this.selectedSidebarCategoryIds
    );

    this.currentUser
      .save(["sidebar_category_ids"])
      .then(() => {
        this.args.closeModal();
      })
      .catch((error) => {
        this.currentUser.set("sidebar_category_ids", initialSidebarCategoryIds);
        popupAjaxError(error);
      })
      .finally(() => {
        this.saving = false;
      });
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
        {{else if (gt this.filteredCategoriesGroupings.length 0)}}
          {{#each this.filteredCategoriesGroupings as |categories|}}
            <div
              class="sidebar-categories-form__row"
              style={{borderColor (get categories "0.color") "left"}}
            >

              {{#each categories as |category|}}
                <div
                  class="sidebar-categories-form__category-row"
                  data-category-id={{category.id}}
                  data-category-level={{category.level}}
                >
                  <label
                    class="sidebar-categories-form__category-label"
                    for={{concat
                      "sidebar-categories-form__input--"
                      category.id
                    }}
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

                    <Input
                      id={{concat
                        "sidebar-categories-form__input--"
                        category.id
                      }}
                      class="sidebar-categories-form__input"
                      @type="checkbox"
                      @checked={{includes
                        this.selectedSidebarCategoryIds
                        category.id
                      }}
                      disabled={{not
                        (includes this.filteredCategoryIds category.id)
                      }}
                      {{on "click" (fn this.toggleCategory category.id)}}
                    />
                  </label>
                </div>
              {{/each}}
            </div>
          {{/each}}
        {{else}}
          <div class="sidebar-categories-form__no-categories">
            {{i18n "sidebar.categories_form_modal.no_categories"}}
          </div>
        {{/if}}
      </form>
    </EditNavigationMenuModal>
  </template>
}
