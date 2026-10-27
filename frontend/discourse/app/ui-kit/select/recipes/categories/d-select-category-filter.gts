import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  fetchCategoryPage,
  knownCategories,
} from "discourse/lib/category-source";
import type User from "discourse/models/user";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import type { SelectResolvedOptions } from "discourse/ui-kit/select/-internals/engine/customizations";
import DSelect from "discourse/ui-kit/select/d-select";
import type {
  SelectItem,
  SelectLoadOptions,
  SelectLoadResult,
  SelectSnapshot,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";
import {
  CategoryBadge,
  categoryItem,
  normalizeCategoryName,
} from "./category-renderers.gts";
import type {
  CategoryItem,
  CategoryRecord,
  CategorySettings,
  CategorySite,
  SelectSignature,
} from "./category-types.ts";

/** Shortcut for removing the category filter. */
export const ALL_CATEGORIES_ID = "all-categories";

/** Shortcut for topics in the parent with no subcategory. */
export const NO_CATEGORIES_ID = "no-categories";

/** A topic-list level selector whose caller owns routing. */
interface DSelectCategoryFilterSignature {
  Args: {
    /** Current category, caller-owned row, shortcut, or an empty level. */
    value?:
      | CategoryRecord
      | CategoryItem
      | typeof ALL_CATEGORIES_ID
      | typeof NO_CATEGORIES_ID
      | null;
    /** Parent whose direct children are being browsed. */
    parentCategory?: CategoryRecord;
    /** Caller-ordered local browsing level. Search still uses the site. */
    items?: readonly CategoryRecord[];
    /** Owns rows, order and paging; bypasses the built-in level truncation and footer. */
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
        | CategoryRecord
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
  Blocks: Pick<SelectSignature["Blocks"], "item" | "selection"> & {
    /** Rendered only when browsing omits categories from the level. */
    footer: [
      /** Live select state. */
      state: NonNullable<SelectSignature["Blocks"]["footer"]>[0],
      /** Resolved core and recipe options. */
      options: SelectResolvedOptions,
      /** Categories omitted from the visible level. */
      moreCount: number,
      /** Parent of the level, absent at the top. */
      parentCategory: CategoryRecord | undefined,
    ];
  };
}

/** Narrows a topic list by category, leaving navigation to its caller. */
export default class DSelectCategoryFilter extends Component<DSelectCategoryFilterSignature> {
  @service declare currentUser: User | null;
  @service declare site: CategorySite;
  @service declare siteSettings: CategorySettings;

  @tracked moreCount = 0;
  @tracked private _expanded = false;

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
    const category = knownCategories([value.id])[0];
    if (category) {
      return categoryItem(category);
    }
    return { id: value.id, name: value.name };
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

  get loadContext() {
    return {
      parentCategory: this.args.parentCategory,
      items: this.args.items,
      editing: this.args.editing,
      uncategorized: this.#uncategorized,
      descriptions: this.#descriptions,
      categories: this.site.lazy_load_categories
        ? undefined
        : this.site.sortedCategories,
    };
  }

  @action
  caret(options: SelectResolvedOptions) {
    const icon = this._expanded ? options.caretUpIcon : options.caretDownIcon;
    if (typeof icon === "string") {
      return icon;
    }
    return this._expanded ? "angle-down" : "angle-right";
  }

  @action
  load(
    query: string,
    opts: SelectLoadOptions
  ): SelectLoadResult | Promise<SelectLoadResult> {
    if (this.args.load) {
      this.moreCount = 0;
      return this.args.load(query, opts);
    }
    if (this.site.lazy_load_categories) {
      return this.#loadPage(query, opts);
    }
    const parent = this.args.parentCategory;
    const uncategorized = this.#uncategorized;
    const uncategorizedId = this.site.uncategorized_category_id;
    const descriptions = this.#descriptions;
    this.moreCount = 0;
    if (!query) {
      const categories = (this.args.items ?? []).filter(
        (category) => uncategorized || category.id !== uncategorizedId
      );
      return this.#localPage(categories, opts, descriptions);
    }
    const term = normalizeCategoryName(query);
    const buckets: CategoryRecord[][] = Array.from({ length: 8 }, () => []);
    for (const category of this.site.sortedCategories) {
      if (
        (!uncategorized && category.id === uncategorizedId) ||
        (parent && category.parent_category_id !== parent.id)
      ) {
        continue;
      }
      const name = normalizeCategoryName(category.name);
      if (!name.includes(term)) {
        continue;
      }
      const rank =
        Number(!!category.parent_category_id) * 4 +
        Number(!!category.read_restricted) * 2 +
        Number(!name.startsWith(term));
      buckets[rank].push(category);
    }
    return this.#localPage(buckets.flat(), opts, descriptions);
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
    const category =
      typeof id === "number" || typeof id === "string"
        ? knownCategories([id])[0]
        : undefined;
    if (category) {
      this.args.onChange?.(category);
      return;
    }
    if (this.#isCategoryItem(item)) {
      this.args.onChange?.(item);
    }
  }

  @action
  onClose() {
    this._expanded = false;
  }

  @action
  onShow() {
    this._expanded = true;
  }

  #localPage(
    categories: readonly CategoryRecord[],
    opts: SelectLoadOptions,
    descriptions: boolean
  ) {
    const offset = opts.offset ?? 0;
    return {
      items: categories
        .slice(offset, offset + 32)
        .map((category) => categoryItem(category, descriptions)),
      total: categories.length,
      hasMore: offset + 32 < categories.length,
    };
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

  async #loadPage(query: string, opts: SelectLoadOptions) {
    const result = await fetchCategoryPage({
      term: query,
      cursor: opts.cursor ?? null,
      parentCategoryId:
        this.args.parentCategory?.id ?? (query ? undefined : -1),
      includeUncategorized: this.#uncategorized,
      signal: opts.signal,
    });
    opts.signal?.throwIfAborted();
    const categories = result.categories.filter(
      (category) =>
        this.#uncategorized ||
        category.id !== this.site.uncategorized_category_id
    );
    this.moreCount = !query && result.total > 18 ? result.total - 15 : 0;
    const shown = this.moreCount ? categories.slice(0, 15) : categories;
    const hasMore = !!query && result.hasMore;
    return {
      items: shown.map((category) =>
        categoryItem(category, this.#descriptions)
      ),
      hasMore,
      total: hasMore ? result.total : undefined,
      cursor: result.cursor,
    };
  }

  <template>
    <DSelect
      class={{if this.filtering "category-drop --filtering" "category-drop"}}
      ...attributes
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @kind="select-category-filter"
      @kindContext={{hash value=@value parentCategory=@parentCategory}}
      @kindOptions={{hash caretDownIcon="angle-right" caretUpIcon="angle-down"}}
      @label={{if @label @label this.levelName}}
      @legacyKind={{if @legacyKind @legacyKind "category-drop"}}
      @load={{this.load}}
      @loadContext={{this.loadContext}}
      @onChange={{this.onChange}}
      @onClose={{this.onClose}}
      @onShow={{this.onShow}}
      @showCaret={{false}}
      @specialItems={{this.specialItems}}
      @suppressFooter={{not this.moreCount}}
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
          <span class="d-category-filter__selection">
            {{~! Keep the badge and caret adjacent. ~}}
            <CategoryBadge @item={{item}} />
            {{~dIcon (this.caret options)~}}
          </span>
        {{/if}}
      </:selection>
      <:footer as |state options|>
        {{#if (has-block "footer")}}
          {{yield state options this.moreCount @parentCategory to="footer"}}
        {{else}}
          {{i18n "categories.plus_more_count" count=this.moreCount}}
        {{/if}}
      </:footer>
    </DSelect>
  </template>
}
