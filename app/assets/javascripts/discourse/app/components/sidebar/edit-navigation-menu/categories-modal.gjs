import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";
import { eq, gt, has } from "truth-helpers";
import DButton from "discourse/components/d-button";
import EditNavigationMenuModal from "discourse/components/sidebar/edit-navigation-menu/modal";
import borderColor from "discourse/helpers/border-color";
import categoryBadge from "discourse/helpers/category-badge";
import dirSpan from "discourse/helpers/dir-span";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

class ActionSerializer {
  constructor(perform) {
    this.perform = perform;
    this.processing = false;
    this.queued = false;
  }

  async trigger() {
    this.queued = true;

    if (!this.processing) {
      this.processing = true;

      while (this.queued) {
        this.queued = false;
        await this.perform();
      }

      this.processing = false;
    }
  }
}

// Given an async method that takes no parameters, produce a method that
// triggers the original method only if it is not currently executing it,
// otherwise it will queue up to one execution of the method
function serialized(target, key, descriptor) {
  const originalMethod = descriptor.value;

  descriptor.value = function () {
    this[`_${key}_serializer`] ||= new ActionSerializer(() =>
      originalMethod.apply(this)
    );
    this[`_${key}_serializer`].trigger();
  };

  return descriptor;
}

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

// categories must be topologically sorted so that the parents appear before
// the children
function findPartialCategories(categories) {
  const categoriesById = new Map(
    categories.map((category) => [category.id, category])
  );
  const subcategoryCounts = new Map();
  const subcategoryCountsRecursive = new Map();
  const partialCategoryInfos = new Map();

  for (const category of categories.slice().reverse()) {
    const count = subcategoryCounts.get(category.parent_category_id) || 0;
    subcategoryCounts.set(category.parent_category_id, count + 1);

    const recursiveCount =
      subcategoryCountsRecursive.get(category.parent_category_id) || 0;

    subcategoryCountsRecursive.set(
      category.parent_category_id,
      recursiveCount + (subcategoryCountsRecursive.get(category.id) || 0) + 1
    );
  }

  for (const [id, count] of subcategoryCounts) {
    if (count === 5 && categoriesById.has(id)) {
      partialCategoryInfos.set(id, {
        level: categoriesById.get(id).level + 1,
        offset: subcategoryCountsRecursive.get(id),
      });
    }
  }

  return partialCategoryInfos;
}

export default class SidebarEditNavigationMenuCategoriesModal extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked initialLoad = true;
  @tracked fetchedCategoriesGroupings = [];
  @tracked
  selectedCategoryIds = new TrackedSet([
    ...this.currentUser.sidebar_category_ids,
  ]);
  selectedFilter = "";
  selectedMode = "everything";
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
    this.subcategoryLoadList = [];
    this.performSearch();
  }

  recomputeGroupings() {
    const categoriesWithShowMores = this.fetchedCategories.flatMap((el, i) => {
      const result = [{ type: "category", category: el }];

      const elID = el.id;
      const elParentID = el.parent_category_id;
      const nextParentID = this.fetchedCategories[i + 1]?.parent_category_id;

      const nextIsSibling = nextParentID === elParentID;
      const nextIsChild = nextParentID === elID;

      if (
        !nextIsSibling &&
        !nextIsChild &&
        this.partialCategoryInfos.has(elParentID)
      ) {
        const { level, offset } = this.partialCategoryInfos.get(elParentID);

        result.push({
          type: "show-more",
          id: elParentID,
          level,
          offset,
        });
      }

      return result;
    }, []);

    this.fetchedCategoriesGroupings = splitWhere(
      categoriesWithShowMores,
      (c) =>
        c.type === "category" && c.category.parent_category_id === undefined
    );
  }

  setFetchedCategories(categories) {
    this.fetchedCategories = categories;
    this.partialCategoryInfos = findPartialCategories(categories);
    this.recomputeGroupings();
  }

  concatFetchedCategories(categories) {
    this.fetchedCategories = this.fetchedCategories.concat(categories);

    // In order to find partially loaded categories correctly, we need to
    // ensure that we account for categories that may have been partially
    // loaded, because the total number of categories in the response clipped
    // them off.
    if (categories[0].parent_category_id !== undefined) {
      const index = this.fetchedCategories.findLastIndex(
        (element) => element.parent_category_id === undefined
      );

      categories = [...this.fetchedCategories.slice(index), ...categories];
    }

    this.partialCategoryInfos = new Map([
      ...this.partialCategoryInfos,
      ...findPartialCategories(categories),
    ]);

    this.recomputeGroupings();
  }

  substituteInFetchedCategories(id, subcategories, offset) {
    this.partialCategoryInfos.delete(id);
    this.recomputeGroupings();

    if (subcategories.length !== 0) {
      const index =
        this.fetchedCategories.findLastIndex(
          (c) => c.parent_category_id === id
        ) + 1;

      this.fetchedCategories = [
        ...this.fetchedCategories.slice(0, index),
        ...subcategories,
        ...this.fetchedCategories.slice(index),
      ];

      this.partialCategoryInfos = new Map([
        ...this.partialCategoryInfos,
        ...findPartialCategories(subcategories),
      ]);

      this.partialCategoryInfos.set(id, {
        offset: offset + subcategories.length,
      });

      this.recomputeGroupings();
    }
  }

  @action
  didInsert(element) {
    this.observer.disconnect();
    this.observer.observe(element);
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

  @serialized
  async performSearch() {
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
      } else if (this.subcategoryLoadList.length !== 0) {
        const { id, offset } = this.subcategoryLoadList.shift();
        const opts = { parentCategoryId: id, offset, ...this.searchOpts() };

        let subcategories = await Category.asyncHierarchicalSearch(
          requestedFilter,
          opts
        );

        this.substituteInFetchedCategories(id, subcategories, offset);
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
    }
  }

  async loadMore() {
    this.loadAnotherPage = true;
    this.debouncedSendRequest();
  }

  @action
  async loadSubcategories(id, offset) {
    this.subcategoryLoadList.push({ id, offset });
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
      <form class="sidebar-categories-form">
        {{#if this.initialLoad}}
          <div class="sidebar-categories-form__loading">
            {{loadingSpinner size="small"}}
          </div>
        {{else}}
          {{#each this.fetchedCategoriesGroupings as |categories|}}
            <div
              style={{borderColor (get categories "0.category.color") "left"}}
              class="sidebar-categories-form__row"
            >
              {{#each categories as |c|}}
                {{#if (eq c.type "category")}}
                  <div
                    {{didInsert this.didInsert}}
                    data-category-id={{c.category.id}}
                    data-category-level={{c.category.level}}
                    class="sidebar-categories-form__category-row"
                  >
                    <label
                      for={{concat
                        "sidebar-categories-form__input--"
                        c.category.id
                      }}
                      class="sidebar-categories-form__category-label"
                    >
                      <div class="sidebar-categories-form__category-wrapper">
                        <div class="sidebar-categories-form__category-badge">
                          {{categoryBadge c.category}}
                        </div>

                        {{#unless c.category.parentCategory}}
                          <div
                            class="sidebar-categories-form__category-description"
                          >
                            {{dirSpan
                              c.category.description_excerpt
                              htmlSafe="true"
                            }}
                          </div>
                        {{/unless}}
                      </div>

                      <input
                        {{on "click" (fn this.toggleCategory c.category.id)}}
                        type="checkbox"
                        checked={{has this.selectedCategoryIds c.category.id}}
                        id={{concat
                          "sidebar-categories-form__input--"
                          c.category.id
                        }}
                        class="sidebar-categories-form__input"
                      />
                    </label>
                  </div>
                {{else}}
                  <div
                    {{didInsert this.didInsert}}
                    data-category-level={{c.level}}
                    class="sidebar-categories-form__category-row"
                  >
                    <label class="sidebar-categories-form__category-label">
                      <div class="sidebar-categories-form__category-wrapper">
                        <div class="sidebar-categories-form__category-badge">
                          <DButton
                            @label="sidebar.categories_form_modal.show_more"
                            @action={{fn this.loadSubcategories c.id c.offset}}
                            class="btn-flat"
                          />
                        </div>
                      </div>
                    </label>
                  </div>
                {{/if}}
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
