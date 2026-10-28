import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";
import Category from "discourse/models/category";
import DSelect from "discourse/ui-kit/select/d-select";
import type {
  SelectControl,
  SelectItem,
  SelectLoadOptions,
  SelectSnapshot,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";
import { CategoryBadge, categoryItem } from "./category-renderers.gts";
import type {
  CategoryItem,
  CategorySettings,
  CategoryValue,
  SelectSignature,
} from "./category-types.ts";

/** Category picker arguments and the engine's forwarded presentation contract. */
interface DSelectCategorySignature {
  Args: Pick<
    SelectSignature["Args"],
    | "maximum"
    | "clearable"
    | "disabled"
    | "label"
    | "id"
    | "describedBy"
    | "invalid"
    | "icon"
    | "variant"
    | "onClose"
    | "identifier"
    | "instanceContext"
    | "legacyKind"
    | "noneLabel"
  > & {
    /** Held ids, numeric strings or category records. */
    value?: CategoryValue | readonly CategoryValue[] | null;
    /** Receives site records by default, or stored ids with `@emit="ids"`. */
    onChange?: (
      value:
        | Category[]
        | Category
        | (number | string)[]
        | number
        | string
        | null
    ) => void;
    /** Output representation; unresolved ids are kept only in ids mode. */
    emit?: "objects" | "ids";
    /** Select several categories. */
    multiple?: boolean;
    /** Requires visibility by default, or permission to create topics. */
    permission?: "see" | "create";
    /** Includes Uncategorized; defaults to true in multiple mode, otherwise the site setting. */
    uncategorized?: boolean;
    /** Includes categories with parents; defaults to true. */
    subcategories?: boolean;
    /** Browses this category's parent's family, or its own family at the top level. */
    scope?: CategoryValue;
    /** Lists the same one-level-up family's tree first while browsing. */
    prioritize?: CategoryValue;
    /** Category ids offered only as disabled rows, described as read-only. */
    disabledCategories?: number | string | readonly (number | string)[];
    /** Categories never offered; a held one stays selected. */
    exclude?: readonly (number | string)[];
    /** Translated text used when empty. */
    placeholder?: string;
    /** Shows transformed plain-text descriptions; defaults to single mode. */
    descriptions?: boolean;
    /** Includes ancestor badges on held selections. */
    showAncestors?: boolean;
    /**
     * Follows each category with children, in a search of two or more characters, with a row
     * that adds the category and every level below it; defaults to multiple mode.
     */
    selectDescendants?: boolean;
    /** Replaces the list source; its rows get no pinned rows and no family footers. */
    load?: SelectSignature["Args"]["load"];
  };
  Element: HTMLElement;
  Blocks: Pick<SelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/** Continues with a value now, or with a promise's value when it settles. */
function then<T, R>(
  value: T | Promise<T>,
  next: (value: T) => R | Promise<R>
): R | Promise<R> {
  return value instanceof Promise ? value.then(next) : next(value);
}

/**
 * Picks categories to store through one search, `Category.searchCategories`, which answers
 * synchronously when the site has every category and from the server otherwise.
 */
export default class DSelectCategory extends Component<DSelectCategorySignature> {
  @service declare siteSettings: CategorySettings;

  get legacyKind() {
    if (this.args.legacyKind) {
      return this.args.legacyKind;
    }
    return this.args.multiple ? "category-selector" : "category-chooser";
  }

  @cached
  get selectedIds() {
    const ids = makeArray(
      this.args.value as CategoryValue | CategoryValue[] | null | undefined
    ).map((entry) => (typeof entry === "object" ? entry.id : Number(entry)));
    return this.args.multiple ? ids : (ids[0] ?? null);
  }

  get #disabledIds(): number[] {
    return makeArray(
      this.args.disabledCategories as number | string | (number | string)[]
    ).map(Number);
  }

  get #uncategorized() {
    return (
      this.args.uncategorized ??
      (this.args.multiple || this.siteSettings.allow_uncategorized_topics)
    );
  }

  get placeholder() {
    // The fallback ports the single chooser's empty header; multiple pickers keep the select's own.
    if (this.args.placeholder || this.args.multiple) {
      return this.args.placeholder;
    }
    return (
      (!this.#disabledIds.length && this.#uncategorized
        ? Category.findUncategorized()?.name
        : undefined) || i18n("category.choose")
    );
  }

  /** Every input of the search; `categories` reloads an open list when the site gains one. */
  get loadContext() {
    return {
      permission: this.args.permission,
      scope: this.args.scope,
      prioritize: this.args.prioritize,
      exclude: this.args.exclude,
      disabledCategories: this.args.disabledCategories,
      uncategorized: this.#uncategorized,
      subcategories: this.args.subcategories,
      descriptions: this.args.descriptions,
      multiple: this.args.multiple,
      selectDescendants: this.args.selectDescendants,
      treeOrder: this.#treeOrder,
      categories: Category.localSearchCategories(),
    };
  }

  get #treeOrder(): "topics" | "position" {
    return this.siteSettings.fixed_category_positions_on_create
      ? "position"
      : "topics";
  }

  @action
  load(query: string, opts: SelectLoadOptions) {
    // The pinned rows and the family ids below read these records synchronously from the site.
    const ids = [
      ...[this.args.scope, this.args.prioritize].map((value) =>
        this.#idOf(value)
      ),
      ...this.#disabledIds,
    ].filter((id) => id != null);
    return then(Category.findByIdsOrLoad(ids), () =>
      // The scope's family root may be a parent the first lookup did not cover.
      then(
        Category.findByIdsOrLoad(
          [this.#familyId(this.args.scope)].filter((id) => id != null)
        ),
        () => this.#search(query, opts)
      )
    );
  }

  @action
  async resolveValues(values: unknown[]) {
    const records = await Category.asyncFindByIds(
      values as (number | string)[]
    );
    return records.map((category) => categoryItem(category));
  }

  @action
  specialItems(snapshot: SelectSnapshot): CategoryItem[] {
    const rows: CategoryItem[] = [];
    if (this.args.multiple && this.args.noneLabel && !snapshot.filter) {
      rows.push({
        id: "category-none",
        name: this.args.noneLabel,
        onSelect: (control) => control.clear(),
      });
    }
    if (!this.args.load) {
      rows.push(...this.#pinned(snapshot.filter));
    }
    return rows;
  }

  /**
   * A family's footer selects its key category and every level below it. It is offered only
   * when the key category's row is shown, so it never acts on a family the search did not show.
   */
  @action
  groupFooter(key: unknown, rows: readonly SelectItem[]): CategoryItem | null {
    const row = key == null ? undefined : rows.find((item) => item.id === key);
    const category = (row as CategoryItem | undefined)?.category;
    if (!category || row!.disabled) {
      return null;
    }
    return {
      id: `category-descendants-${category.id}`,
      name: this.#footerLabel(category),
      category,
      onSelect: (control) => this.#selectFamily(control, category),
    };
  }

  @action
  onChange(value: SelectValue) {
    const ids = makeArray(value) as (number | string)[];
    const result = this.args.emit === "ids" ? ids : Category.findByIds(ids);
    this.args.onChange?.(this.args.multiple ? result : (result[0] ?? null));
  }

  #categoryAllowed() {
    const excluded = new Set((this.args.exclude ?? []).map(Number));
    const onlyPostable = this.args.permission === "create";
    const uncategorized = this.#uncategorized;
    const subcategories = this.args.subcategories !== false;
    return (category: Category) =>
      (!onlyPostable || category.canCreateTopic) &&
      (uncategorized || !category.isUncategorizedCategory) &&
      (subcategories || !category.parent_category_id) &&
      !excluded.has(category.id!);
  }

  #idOf(value?: CategoryValue | null) {
    return value && typeof value === "object" ? value.id : value;
  }

  /** The id of the family one level up from a category: its parent, or itself at the top. */
  #familyId(value?: CategoryValue): number | undefined {
    const category: Category | undefined = Category.findById(this.#idOf(value));
    return category?.parent_category_id || category?.id;
  }

  /**
   * Rows the search leaves out. A scope lists its family's children, so its root is pinned
   * while browsing. Disabled categories are excluded from the search, so they are always
   * offered as pinned rows whenever they match, and are never grouped or given a footer.
   */
  #pinned(query: string): CategoryItem[] {
    const root = query ? undefined : this.#familyId(this.args.scope);
    const roots = Category.findByIds(root == null ? [] : [root]).filter(
      this.#categoryAllowed()
    );
    const disabled = Category.findByIds(this.#disabledIds).filter((category) =>
      Category.matchesSearch(category, query)
    );
    const descriptions = this.args.descriptions ?? !this.args.multiple;
    const readOnlyDescription = i18n("category_row.read_only_description");
    return [...new Set([...roots, ...disabled])].map((category) => {
      const row = categoryItem(category, descriptions);
      if (disabled.includes(category)) {
        row.disabled = true;
        row.description = readOnlyDescription;
      }
      return row;
    });
  }

  #offersDescendants(query: string) {
    return (
      query.length >= 2 &&
      this.args.multiple &&
      this.args.selectDescendants !== false &&
      this.args.subcategories !== false
    );
  }

  /**
   * Only a family's own category keeps its key, so it groups alone and its footer comes right
   * after it, before the rest of the family. The key comes from the search that ordered the
   * rows, so a later site update can never re-key a row that is already shown.
   */
  #search(query: string, opts: SelectLoadOptions) {
    const groupFamilies = this.#offersDescendants(query);
    const search = Category.searchCategories(query, {
      groupFamilies: groupFamilies || undefined,
      includeAncestors: true,
      includeSubcategories: this.args.subcategories !== false,
      includeUncategorized: this.#uncategorized,
      onlyPostable: this.args.permission === "create",
      page: opts.page,
      parentCategoryId: query ? undefined : this.#familyId(this.args.scope),
      prioritizedCategoryId: query
        ? undefined
        : this.#familyId(this.args.prioritize),
      rejectCategoryIds: [
        ...new Set([
          ...(this.args.exclude ?? []).map(Number),
          ...this.#disabledIds,
        ]),
      ],
      treeOrder: query ? undefined : this.#treeOrder,
    });
    const descriptions = this.args.descriptions ?? !this.args.multiple;
    return then(search, ({ categories, categoriesCount, familyKeys }) => ({
      items: categories.map((category) => {
        const row = categoryItem(category, descriptions);
        if (groupFamilies && familyKeys?.[category.id!] === category.id) {
          row.familyKey = category.id;
        }
        return row;
      }),
      total: categoriesCount,
    }));
  }

  /**
   * The footer names its category's own topic count, as the badge it draws shows it. The badge
   * draws no count of zero, so neither does the label.
   */
  #footerLabel(category: Category) {
    const count = category.topic_count;
    return count
      ? i18n("category.select_with_subcategories_count", {
          category: category.displayName,
          count,
        })
      : i18n("category.select_with_subcategories", {
          category: category.displayName,
        });
  }

  #selectFamily(control: SelectControl, category: Category) {
    void control.update(async (scope) => {
      const descendants: Category[] =
        await Category.asyncFindDescendants(category);
      const allowed = this.#categoryAllowed();
      const locked = new Set(this.#disabledIds);
      scope.selectMany(
        descendants
          .filter((child) => !locked.has(child.id!) && allowed(child))
          .map((child) => categoryItem(child))
      );
    });
  }

  <template>
    <DSelect
      ...attributes
      @clearable={{@clearable}}
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @groupBy="familyKey"
      @groupDividers={{false}}
      @groupFooter={{this.groupFooter}}
      @icon={{@icon}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @kind="select-category"
      @kindContext={{hash
        value=@value
        permission=(if @permission @permission "see")
        scope=@scope
        exclude=@exclude
      }}
      @label={{if @label @label this.placeholder}}
      @legacyKind={{this.legacyKind}}
      @load={{if @load @load this.load}}
      @loadContext={{this.loadContext}}
      @maximum={{@maximum}}
      @multiple={{@multiple}}
      @noneLabel={{@noneLabel}}
      @onChange={{this.onChange}}
      @onClose={{@onClose}}
      @placeholder={{this.placeholder}}
      @resolveValues={{this.resolveValues}}
      @specialItems={{this.specialItems}}
      @suppressFooter={{not (has-block "footer")}}
      @value={{this.selectedIds}}
      @variant={{@variant}}
    >
      <:item as |item options|>
        {{#if (has-block "item")}}
          {{yield item options to="item"}}
        {{else}}
          <CategoryBadge @ancestors={{true}} @counts={{true}} @item={{item}} />
        {{/if}}
      </:item>
      <:groupFooter as |item|>
        <CategoryBadge @counts={{true}} @family={{true}} @item={{item}} />
      </:groupFooter>
      <:selection as |item options|>
        {{#if (has-block "selection")}}
          {{yield item options to="selection"}}
        {{else}}
          <CategoryBadge @ancestors={{@showAncestors}} @item={{item}} />
        {{/if}}
      </:selection>
      <:footer as |state options|>
        {{yield state options to="footer"}}
      </:footer>
    </DSelect>
  </template>
}
