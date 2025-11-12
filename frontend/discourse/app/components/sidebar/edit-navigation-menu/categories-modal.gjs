import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";
import DButton from "discourse/components/d-button";
import EditNavigationMenuModal from "discourse/components/sidebar/edit-navigation-menu/modal";
import borderColor from "discourse/helpers/border-color";
import categoryBadge from "discourse/helpers/category-badge";
import concatClass from "discourse/helpers/concat-class";
import dirSpan from "discourse/helpers/dir-span";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { serializedAction, splitWhere } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import { eq, gt, has } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

// This modal is used to display a deep category tree (categories →
// subcategories → sub-subcategories) but only load 5 items at a time for
// performance, so there are some contortions we have to perform to load the
// categories in the correct place.
//
// The key properties are:
//
// - fetchedCategories - Flat array of all loaded categories, stored in
//     hierarchical order (parents before children)
// - partialCategoryInfos - Map tracking which parents have exactly 5 children
//     (meaning "might have more to load")
//
// The overall algorithm is:
//
// 1. Initial Load: Fetch first 5 categories from server in hierarchical order
//   - Example:
//     - grandparent
//       - parent1
//         - child1
//         - child2
//         - child3
//       - parent2
//       - parent3
//       - ...
//
// 2. Detect partially loaded categories (findPartialCategories):
//   - Count how many children each category has
//   - If there are exactly 5, mark as "partial" (might have more since 5 is the page size)
//   - Store the parent's ID and offset (how many to skip when loading more)
//
// 3. Display with buttons (recomputeGroupings):
//   - Loop through fetchedCategories
//   - Insert "Show more" button after the last child of any partial parent
//   - Button contains parent ID, level, and offset
//
// 4. Click "Show more":
//   - Call backend to get more children of parent X, starting at offset Y
//   - Backend returns next batch (e.g., [child6, child7, ...])
//
// 5. Insert new categories (substituteInFetchedCategories):
//   - Find where the last child of that parent is
//   - Scan past any descendants (grandchildren, etc.)
//   - Insert new categories after all existing descendants
//   - Recalculate which parents are still partial
export default class SidebarEditNavigationMenuCategoriesModal extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked initialLoad = true;
  @tracked filtered = false;
  @tracked fetchedCategoriesGroupings = [];
  @tracked
  selectedCategoryIds = new TrackedSet([
    ...this.currentUser.sidebar_category_ids,
  ]);
  selectedFilter = "";
  selectedMode = "everything";
  fetchedCategories;
  partialCategoryInfos;
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
      const nextCategory = this.fetchedCategories[i + 1];
      const nextParentID = nextCategory?.parent_category_id;

      const nextIsSibling = nextParentID === elParentID;
      const nextIsChild = nextParentID === elID;

      if (!nextIsSibling && !nextIsChild) {
        // When leaving a subtree, check all ancestor levels to see if any need
        // a "Show more" button. This handles cases where the last sibling has
        // descendants - we need to show the parent's button after those descendants.
        const categoriesById = new Map(
          this.fetchedCategories.map((c) => [c.id, c])
        );

        const checkAncestor = (ancestorId) => {
          if (this.partialCategoryInfos.has(ancestorId)) {
            // Check if there are more children of this ancestor after the current element
            const hasMoreChildrenAfter = this.fetchedCategories
              .slice(i + 1)
              .some((cat) => cat.parent_category_id === ancestorId);

            if (!hasMoreChildrenAfter) {
              const { level, offset } =
                this.partialCategoryInfos.get(ancestorId);

              result.push({
                type: "show-more",
                id: ancestorId,
                level,
                offset,
              });
            }
          }
        };

        let currentAncestorId = elParentID;
        while (currentAncestorId !== undefined) {
          checkAncestor(currentAncestorId);

          // Move up to the next ancestor
          const ancestor = categoriesById.get(currentAncestorId);
          currentAncestorId = ancestor?.parent_category_id;
        }
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
    this.partialCategoryInfos = this.findPartialCategories(categories);
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

    // Recalculate the partialCategoryInfos using the full set of categories
    // to properly identify categories that now have exactly 5 subcategories
    // after loading more via the intersection observer
    this.partialCategoryInfos = this.findPartialCategories(
      this.fetchedCategories
    );

    this.recomputeGroupings();
  }

  substituteInFetchedCategories(id, subcategories, offset) {
    this.partialCategoryInfos.delete(id);
    this.recomputeGroupings();

    if (subcategories.length !== 0) {
      // Find the last direct child of the parent
      const lastDirectChildIndex = this.fetchedCategories.findLastIndex(
        (c) => c.parent_category_id === id
      );

      if (lastDirectChildIndex === -1) {
        // No existing children, insert after the parent itself if it exists
        const parentIndex = this.fetchedCategories.findIndex(
          (c) => c.id === id
        );
        const index = parentIndex !== -1 ? parentIndex + 1 : 0;
        this.fetchedCategories = [
          ...this.fetchedCategories.slice(0, index),
          ...subcategories,
          ...this.fetchedCategories.slice(index),
        ];
      } else {
        // Find the last descendant of the last direct child by looking for the
        // next category that is not a descendant of any child of id
        const childrenIds = this.fetchedCategories
          .filter((c) => c.parent_category_id === id)
          .map((c) => c.id);

        const categoriesById = new Map(
          this.fetchedCategories.map((c) => [c.id, c])
        );

        const isDescendantOfChild = (category) => {
          let currentCategory = category;
          while (
            currentCategory &&
            currentCategory.parent_category_id !== undefined
          ) {
            if (childrenIds.includes(currentCategory.parent_category_id)) {
              return true;
            }
            currentCategory = categoriesById.get(
              currentCategory.parent_category_id
            );
          }
          return false;
        };

        let insertIndex = lastDirectChildIndex + 1;
        while (insertIndex < this.fetchedCategories.length) {
          if (!isDescendantOfChild(this.fetchedCategories[insertIndex])) {
            break;
          }
          insertIndex++;
        }

        this.fetchedCategories = [
          ...this.fetchedCategories.slice(0, insertIndex),
          ...subcategories,
          ...this.fetchedCategories.slice(insertIndex),
        ];
      }

      // Recalculate partial categories based on the full set of categories
      // to ensure we properly identify categories with exactly 5 subcategories
      this.partialCategoryInfos = this.findPartialCategories(
        this.fetchedCategories
      );

      // Only show "Show more" button if exactly 5 subcategories were returned,
      // which is the default page size and indicates there might be more to load.
      // If we received fewer than 5, we've reached the end of the subcategories.
      if (subcategories.length === 5) {
        if (id === undefined) {
          // Root level categories
          this.partialCategoryInfos.set(id, {
            level: 0,
            offset: offset + subcategories.length,
          });
        } else {
          const parentCategory = this.fetchedCategories.find(
            (c) => c.id === id
          );
          if (parentCategory) {
            this.partialCategoryInfos.set(id, {
              level: parentCategory.level + 1,
              offset: offset + subcategories.length,
            });
          }
        }
      }

      this.recomputeGroupings();
    }
  }

  // Count how many children each category has:
  //
  //  - If there are exactly 5, mark as "partial" (might have more since 5 is the page size)
  //  - Store the parent's ID and offset (how many to skip when loading more)
  //
  // Categories must be topologically sorted so that the parents appear before
  // the children.
  findPartialCategories(categories) {
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
      if (count === 5) {
        if (id === undefined) {
          // Root level categories (parent_category_id is undefined)
          partialCategoryInfos.set(id, {
            level: 0,
            offset: subcategoryCountsRecursive.get(id),
          });
        } else if (categoriesById.has(id)) {
          partialCategoryInfos.set(id, {
            level: categoriesById.get(id).level + 1,
            offset: subcategoryCountsRecursive.get(id),
          });
        }
      }
    }

    return partialCategoryInfos;
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
        const opts = { offset, ...this.searchOpts() };

        // Only add parentCategoryId if it's not undefined (for root categories)
        if (id !== undefined) {
          opts.parentCategoryId = id;
        }

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
      this.filtered = true;
    }
  }

  @action
  async loadMore() {
    this.loadAnotherPage = true;
    this.debouncedSendRequest();
  }

  @action
  loadSubcategories(id, offset) {
    this.subcategoryLoadList.push({ id, offset });
    this.performSearch();
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
      <form
        class={{concatClass
          "sidebar-categories-form"
          (if this.filtered "--filtered")
        }}
      >
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
                    data-test-category-id={{c.id}}
                  >
                    <label class="sidebar-categories-form__category-label">
                      <div class="sidebar-categories-form__category-wrapper">
                        <div class="sidebar-categories-form__category-badge">
                          <DButton
                            @label="sidebar.categories_form_modal.show_more"
                            @action={{fn this.loadSubcategories c.id c.offset}}
                            class="sidebar-categories-form__show-more-btn btn-flat"
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
