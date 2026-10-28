import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Category from "discourse/models/category";
import type Site from "discourse/models/site";
import type User from "discourse/models/user";
import DSelect from "discourse/ui-kit/select/d-select";
import type {
  SelectItem,
  SelectLoadOptions,
  SelectLoadResult,
  SelectSnapshot,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";
import { CategoryBadge, categoryItem } from "./category-renderers.gts";
import type {
  CategoryItem,
  CategorySettings,
  SelectSignature,
} from "./category-types.ts";
import { continueWith } from "./continue-with.ts";

/** Shortcut for removing the category filter. */
export const ALL_CATEGORIES_ID = "all-categories";

/** Shortcut for topics in the parent with no subcategory. */
export const NO_CATEGORIES_ID = "no-categories";

/** A topic-list level selector whose caller owns routing. */
interface DSelectCategoryFilterSignature {
  Args: {
    /** Current category, caller-owned row, shortcut, or an empty level. */
    value?:
      | Category
      | CategoryItem
      | typeof ALL_CATEGORIES_ID
      | typeof NO_CATEGORIES_ID
      | null;
    /** Parent whose direct children are being browsed. */
    parentCategory?: Category;
    /** The level a preloaded site browses, in the caller's order. Searches and lazy sites use the model. */
    items?: readonly Category[];
    /** Owns rows, order and paging in place of the model's search. */
    load?: SelectSignature["Args"]["load"];
    /** Names an empty level as no subcategories. */
    noSubcategories?: boolean;
    /** Omits the shortcut back to every category. */
    editing?: boolean;
    /** Includes subcategories' topics in option counts. */
    countSubcategories?: boolean;
    /** Includes Uncategorized; defaults to the site setting. */
    uncategorized?: boolean;
    /** Accessible control name; defaults to the level's name. */
    label?: string;
    /** Receives a site category, the caller's unloaded row, or a shortcut; never navigates. */
    onChange?: (
      value:
        | Category
        | CategoryItem
        | typeof ALL_CATEGORIES_ID
        | typeof NO_CATEGORIES_ID
    ) => void;
    /** Temporary compatibility identity; defaults to category-drop. */
    legacyKind?: SelectSignature["Args"]["legacyKind"];
    /** Call-site customization identity. */
    identifier?: string;
    /** Call-site state exposed to customizations. */
    instanceContext?: object;
  };
  Element: HTMLElement;
  Blocks: Pick<SelectSignature["Blocks"], "item" | "selection">;
}

/** Narrows a topic list by category, leaving navigation to its caller. */
export default class DSelectCategoryFilter extends Component<DSelectCategoryFilterSignature> {
  @service declare currentUser: User | null;
  @service declare site: Site;
  @service declare siteSettings: CategorySettings;

  get levelName() {
    if (this.args.noSubcategories || this.args.value === NO_CATEGORIES_ID) {
      return i18n("categories.no_subcategories");
    }
    return i18n(
      this.args.parentCategory
        ? "categories.subcategories_label"
        : "categories.categories_label"
    );
  }

  get filtering() {
    return this.selection.id !== ALL_CATEGORIES_ID;
  }

  get selection(): CategoryItem {
    const value = this.args.value;
    if (typeof value !== "object" || !value) {
      return { id: value ?? ALL_CATEGORIES_ID, name: this.levelName };
    }
    const category: Category | undefined = Category.findById(value.id);
    if (category) {
      return categoryItem(category);
    }
    return { id: value.id!, name: value.name ?? "" };
  }

  get #uncategorized() {
    return (
      this.args.uncategorized ?? this.siteSettings.allow_uncategorized_topics
    );
  }

  get #descriptions() {
    return (
      !this.currentUser || (!this.currentUser.staff && this.currentUser.isBasic)
    );
  }

  /** Lazy levels list in the order a preloaded site's `categoriesList` keeps. */
  get #treeOrder(): "topics" | "position" {
    return this.siteSettings.fixed_category_positions ? "position" : "topics";
  }

  get loadContext() {
    return {
      parentCategory: this.args.parentCategory,
      items: this.args.items,
      uncategorized: this.#uncategorized,
      descriptions: this.#descriptions,
      categories: Category.localSearchCategories(),
      treeOrder: this.#treeOrder,
    };
  }

  @action
  load(
    query: string,
    opts: SelectLoadOptions
  ): SelectLoadResult | Promise<SelectLoadResult> {
    if (this.args.load) {
      return this.args.load(query, opts);
    }
    if (!query && !this.site.lazy_load_categories) {
      return (this.args.items ?? [])
        .filter(
          (category) => this.#uncategorized || !category.isUncategorizedCategory
        )
        .map((category) => categoryItem(category, this.#descriptions));
    }
    const search = Category.searchCategories(query, {
      includeAncestors: true,
      includeUncategorized: this.#uncategorized,
      page: opts.page,
      // Browsing keeps to the level; a search at the top spans the site.
      parentCategoryId:
        this.args.parentCategory?.id ?? (query ? undefined : -1),
      treeOrder: query ? undefined : this.#treeOrder,
    });
    return continueWith(search, ({ categories, categoriesCount }) => ({
      items: categories.map((category) =>
        categoryItem(category, this.#descriptions)
      ),
      total: categoriesCount,
    }));
  }

  @action
  specialItems(snapshot: SelectSnapshot) {
    return this.#shortcuts(snapshot.filter);
  }

  @action
  onChange(id: SelectValue, item: SelectItem | SelectItem[] | null) {
    if (id === ALL_CATEGORIES_ID || id === NO_CATEGORIES_ID) {
      this.args.onChange?.(id);
      return;
    }
    if (!item || Array.isArray(item)) {
      return;
    }
    const category = Category.findById(id as number | string);
    if (category) {
      this.args.onChange?.(category);
      return;
    }
    if (this.#isCategoryItem(item)) {
      this.args.onChange?.(item);
    }
  }

  #shortcuts(query: string): CategoryItem[] {
    if (query) {
      return [];
    }
    const shortcuts: CategoryItem[] = [];
    if (
      this.args.value &&
      this.args.value !== ALL_CATEGORIES_ID &&
      !this.args.editing
    ) {
      shortcuts.push({
        id: ALL_CATEGORIES_ID,
        name: i18n("categories.remove_filter"),
      });
    }
    if (this.args.parentCategory) {
      shortcuts.push({
        id: NO_CATEGORIES_ID,
        name: i18n("categories.no_subcategories"),
      });
    }
    return shortcuts;
  }

  #isCategoryItem(item: SelectItem): item is CategoryItem {
    return (
      (typeof item.id === "number" || typeof item.id === "string") &&
      typeof item.name === "string"
    );
  }

  <template>
    <DSelect
      class={{if this.filtering "category-drop --filtering" "category-drop"}}
      ...attributes
      @caretIcon={{hash closed="angle-right" open="angle-down"}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @kind="select-category-filter"
      @kindContext={{hash value=@value parentCategory=@parentCategory}}
      @label={{if @label @label this.levelName}}
      @legacyKind={{if @legacyKind @legacyKind "category-drop"}}
      @load={{this.load}}
      @loadContext={{this.loadContext}}
      @onChange={{this.onChange}}
      @specialItems={{this.specialItems}}
      @value={{this.selection.id}}
      @valueItems={{this.selection}}
      @variant="button"
    >
      <:item as |item options|>
        {{#if (has-block "item")}}
          {{yield item options to="item"}}
        {{else}}
          <CategoryBadge
            @ancestors={{not @parentCategory}}
            @counts={{true}}
            @countSubcategories={{@countSubcategories}}
            @item={{item}}
          />
        {{/if}}
      </:item>
      <:selection as |item options|>
        {{#if (has-block "selection")}}
          {{yield item options to="selection"}}
        {{else}}
          <CategoryBadge @item={{item}} />
        {{/if}}
      </:selection>
    </DSelect>
  </template>
}
