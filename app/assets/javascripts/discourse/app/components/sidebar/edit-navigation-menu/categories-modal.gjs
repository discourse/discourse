import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import EditNavigationMenuModal from "discourse/components/sidebar/edit-navigation-menu/modal";
import borderColor from "discourse/helpers/border-color";
import categoryBadge from "discourse/helpers/category-badge";
import dirSpan from "discourse/helpers/dir-span";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import { INPUT_DELAY } from "discourse-common/config/environment";
import i18n from "discourse-common/helpers/i18n";
import discourseDebounce from "discourse-common/lib/debounce";
import gt from "truth-helpers/helpers/gt";
import includes from "truth-helpers/helpers/includes";
import not from "truth-helpers/helpers/not";

export default class extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked filter = "";
  @tracked filteredCategoryIds;
  @tracked onlySelected = false;
  @tracked onlyUnselected = false;

  @tracked
  selectedSidebarCategoryIds = [...this.currentUser.sidebar_category_ids];

  categoryGroupings = [];

  constructor() {
    super(...arguments);

    let categories = [...this.site.categories];

    if (!this.siteSettings.fixed_category_positions) {
      categories.sort((a, b) => a.name.localeCompare(b.name));
    }

    Category.sortCategories(categories).reduce(
      (categoryGrouping, category, index, arr) => {
        if (category.isUncategorizedCategory) {
          return categoryGrouping;
        }

        categoryGrouping.push(category);

        const nextCategory = arr[index + 1];

        if (!nextCategory || nextCategory.level === 0) {
          this.categoryGroupings.push(categoryGrouping);
          return [];
        }

        return categoryGrouping;
      },
      []
    );
  }

  get filteredCategoriesGroupings() {
    const filteredCategoryIds = new Set();

    const groupings = this.categoryGroupings.reduce((acc, categoryGrouping) => {
      const filteredCategories = new Set();

      const addCategory = (category) => {
        if (this.#matchesFilter(category)) {
          if (category.parentCategory?.parentCategory) {
            filteredCategories.add(category.parentCategory.parentCategory);
          }

          if (category.parentCategory) {
            filteredCategories.add(category.parentCategory);
          }

          filteredCategoryIds.add(category.id);
          filteredCategories.add(category);
        }
      };

      categoryGrouping.forEach((category) => {
        if (this.onlySelected) {
          if (this.selectedSidebarCategoryIds.includes(category.id)) {
            addCategory(category);
          }
        } else if (this.onlyUnselected) {
          if (!this.selectedSidebarCategoryIds.includes(category.id)) {
            addCategory(category);
          }
        } else {
          addCategory(category);
        }
      });

      if (filteredCategories.size > 0) {
        acc.push(Array.from(filteredCategories));
      }

      return acc;
    }, []);

    this.filteredCategoryIds = Array.from(filteredCategoryIds);
    return groupings;
  }

  #matchesFilter(category) {
    return this.filter.length === 0 || category.nameLower.includes(this.filter);
  }

  @action
  resetFilter() {
    this.onlySelected = false;
    this.onlyUnselected = false;
  }

  @action
  filterSelected() {
    this.onlySelected = true;
    this.onlyUnselected = false;
  }

  @action
  filterUnselected() {
    this.onlySelected = false;
    this.onlyUnselected = true;
  }

  @action
  onFilterInput(filter) {
    discourseDebounce(this, this.#performFiltering, filter, INPUT_DELAY);
  }

  #performFiltering(filter) {
    this.filter = filter.toLowerCase();
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
        {{#if (gt this.filteredCategoriesGroupings.length 0)}}
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
