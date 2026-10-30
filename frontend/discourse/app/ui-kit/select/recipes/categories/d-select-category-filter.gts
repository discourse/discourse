import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { warn } from "@ember/debug";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Category from "discourse/models/category";
import type User from "discourse/models/user";
import DSelect from "discourse/ui-kit/select/d-select";
import {
  renderSelectText,
  type SelectItem,
  type SelectLoadOptions,
  type SelectLoadResult,
  type SelectResolvedOptions,
  type SelectSnapshot,
  type SelectTexts,
  type SelectValue,
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
    /** Owns rows, order and paging in place of the model's search. */
    load?: SelectSignature["Args"]["load"];
    /** Holds the no-subcategories filter while no category is held. */
    noSubcategories?: boolean;
    /** Omits the shortcut back to every category. */
    editing?: boolean;
    /** Includes subcategories' topics in option counts. */
    countSubcategories?: boolean;
    /** Includes Uncategorized; defaults to the site setting. */
    uncategorized?: boolean;
    /** Accessible control name; defaults to what the level filters. The held value follows it. */
    ariaLabel?: string;
    /** Text for an empty level; defaults to the level's name. */
    placeholder?: string;
    /**
     * The drop's texts, over the recipe's: `ariaLabel` and `placeholder` default to the level's
     * name, and `removeFilter` and `noSubcategories` name the shortcuts.
     */
    texts?: SelectSignature["Args"]["texts"];
    /** Receives a site category or a shortcut; never navigates. */
    onChange?: (
      value: Category | typeof ALL_CATEGORIES_ID | typeof NO_CATEGORIES_ID
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
  @service declare siteSettings: CategorySettings;

  /** The recipe's texts; the name and the empty text follow the level being browsed. */
  kindTexts: SelectTexts = {
    ariaLabel: () =>
      i18n(
        this.args.parentCategory
          ? "categories.filter_by_subcategories_label"
          : "categories.filter_by_categories_label"
      ),
    placeholder: () =>
      i18n(
        this.args.parentCategory
          ? "categories.subcategories_label"
          : "categories.categories_label"
      ),
    removeFilter: { key: "categories.remove_filter" },
    noSubcategories: { key: "categories.no_subcategories" },
  };

  /** The call site's texts, under which the old text arguments still apply. */
  get texts(): SelectTexts | undefined {
    const { ariaLabel, placeholder, texts } = this.args;
    if (!ariaLabel && !placeholder) {
      return texts;
    }
    return {
      ariaLabel: ariaLabel || undefined,
      placeholder: placeholder || undefined,
      ...Object.fromEntries(
        Object.entries(texts ?? {}).filter(([, text]) => text != null)
      ),
    };
  }

  get filtering() {
    return this.heldId !== undefined;
  }

  /** The held filter. An empty level and the "all" shortcut hold nothing, so the placeholder shows. */
  get heldId(): number | string | undefined {
    const value = this.args.value;
    if (
      value === NO_CATEGORIES_ID ||
      (value == null && this.args.noSubcategories)
    ) {
      return NO_CATEGORIES_ID;
    }
    return typeof value === "object" && value ? value.id! : undefined;
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

  /** Levels list in the order the site's `categoriesList` keeps. */
  get #treeOrder(): "topics" | "position" {
    return this.siteSettings.fixed_category_positions ? "position" : "topics";
  }

  /**
   * Every input of the load; `categories` reloads an open list when the site gains one, and
   * `muted` when the user's mutes change.
   */
  get loadContext() {
    return {
      parentCategory: this.args.parentCategory,
      muted: this.currentUser?.get("indirectly_muted_category_ids") as
        | number[]
        | undefined,
      uncategorized: this.#uncategorized,
      descriptions: this.#descriptions,
      categories: Category.localSearchCategories(),
      treeOrder: this.#treeOrder,
    };
  }

  /** The held filter's row, built from the options so a customized shortcut name reaches it. */
  @action
  valueItems(options: SelectResolvedOptions): CategoryItem[] {
    const id = this.heldId;
    if (id === NO_CATEGORIES_ID) {
      return [{ id, name: renderSelectText(options, "noSubcategories") }];
    }
    const value = this.args.value;
    if (id === undefined || typeof value !== "object" || !value) {
      return [];
    }
    const category: Category | undefined = Category.findById(id);
    return [category ? categoryItem(category) : { id, name: value.name ?? "" }];
  }

  /**
   * Browses and searches through the shared category search. It leaves out what the user mutes
   * only through a parent, the set the navigation drops from its own category list.
   */
  @action
  load(
    query: string,
    opts: SelectLoadOptions
  ): SelectLoadResult | Promise<SelectLoadResult> {
    if (this.args.load) {
      return this.args.load(query, opts);
    }
    const search = Category.searchCategories(query, {
      includeAncestors: true,
      includeUncategorized: this.#uncategorized,
      rejectIndirectlyMuted: true,
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

  /** Shortcuts lead the level while browsing and are left out of searches. */
  @action
  specialItems(snapshot: SelectSnapshot, options: SelectResolvedOptions) {
    return this.#shortcuts(snapshot.filter, options);
  }

  /**
   * Emits the site's category or a shortcut id. A row the site does not know, which only a
   * caller's loader or a customization can supply, cannot be routed, so its pick is dropped.
   */
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
    } else if (DEBUG) {
      warn(
        `DSelectCategoryFilter: dropped a pick of row ${String(id)}, which is not a site category`,
        false,
        { id: "discourse.d-select-category-filter.unknown-row" }
      );
    }
  }

  #shortcuts(query: string, options: SelectResolvedOptions): CategoryItem[] {
    if (query) {
      return [];
    }
    const shortcuts: CategoryItem[] = [];
    const held = this.heldId;
    if (held !== undefined && !this.args.editing) {
      shortcuts.push({
        id: ALL_CATEGORIES_ID,
        name: renderSelectText(options, "removeFilter"),
      });
    }
    if (this.args.parentCategory && held !== NO_CATEGORIES_ID) {
      shortcuts.push({
        id: NO_CATEGORIES_ID,
        name: renderSelectText(options, "noSubcategories"),
      });
    }
    return shortcuts;
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
      @kindTexts={{this.kindTexts}}
      @legacyKind={{if @legacyKind @legacyKind "category-drop"}}
      @load={{this.load}}
      @loadContext={{this.loadContext}}
      @onChange={{this.onChange}}
      @specialItems={{this.specialItems}}
      @texts={{this.texts}}
      @value={{this.heldId}}
      @valueItems={{this.valueItems}}
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
