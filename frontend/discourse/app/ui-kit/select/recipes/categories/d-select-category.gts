import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  fetchCategoryPage,
  knownCategories,
  loadDescendants,
  resolveCategories,
} from "discourse/lib/category-source";
import Category from "discourse/models/category";
import DSelect from "discourse/ui-kit/select/d-select";
import type {
  SelectLoadOptions,
  SelectSnapshot,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";
import {
  CategoryBadge,
  categoryItem,
  decodeCategoryText,
  normalizeCategoryName,
} from "./category-renderers.gts";
import type {
  CategoryItem,
  CategoryRecord,
  CategorySettings,
  CategorySite,
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
        | CategoryRecord[]
        | CategoryRecord
        | (number | string)[]
        | number
        | string
        | null
    ) => void;
    /** Output representation; unresolved ids are kept only in ids mode. */
    emit?: "objects" | "ids";
    /** Select several categories; defaults to true. */
    multiple?: boolean;
    /** Requires visibility by default, or permission to create topics. */
    permission?: "see" | "create";
    /** Includes Uncategorized; defaults to true in multiple mode, otherwise the site setting. */
    uncategorized?: boolean;
    /** Includes categories with parents; defaults to true. */
    subcategories?: boolean;
    /** Browses this category's parent's family, or its own family at the top level. */
    scope?: CategoryValue;
    /** Puts the same one-level-up family first while browsing. */
    prioritize?: CategoryValue;
    /** Category ids always offered as disabled rows while browsing. */
    readOnly?: number | string | readonly (number | string)[];
    /** Categories hidden unless already held. */
    exclude?: readonly (number | string)[];
    /** Translated text used when empty. */
    placeholder?: string;
    /** Shows transformed plain-text descriptions; defaults to single mode. */
    descriptions?: boolean;
    /** Includes ancestor badges on held selections. */
    showAncestors?: boolean;
    /** Offers bulk descendant selection after two search characters; defaults to multiple mode. */
    selectDescendants?: boolean;
    /** Replaces the list source without changing the selection contract. */
    load?: SelectSignature["Args"]["load"];
  };
  Element: HTMLElement;
  Blocks: Pick<SelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/** Picks categories to store and leaves loading and update authority with DSelect. */
export default class DSelectCategory extends Component<DSelectCategorySignature> {
  @service declare site: CategorySite;
  @service declare siteSettings: CategorySettings;

  get multiple() {
    return this.args.multiple !== false;
  }

  get legacyKind() {
    if (this.args.legacyKind) {
      return this.args.legacyKind;
    }
    return this.multiple ? "category-selector" : "category-chooser";
  }

  @cached
  private get _ids(): (number | string)[] {
    const value = this.args.value;
    if (value == null) {
      return [];
    }
    const values = Array.isArray(value) ? value : [value];
    return values.map((entry: CategoryValue) =>
      typeof entry === "object" ? entry.id : Number(entry)
    );
  }

  get value() {
    return this.multiple ? this._ids : (this._ids[0] ?? null);
  }

  get #heldExcludedKey() {
    if (!this.args.exclude?.length) {
      return "";
    }
    const held = new Set(this._ids);
    return this.args.exclude
      .map(Number)
      .filter((id) => held.has(id))
      .sort((a, b) => a - b)
      .join(",");
  }

  get #readOnly(): number[] {
    const value = this.args.readOnly;
    if (value == null) {
      return [];
    }
    const ids = Array.isArray(value) ? value : [value];
    return ids.map(Number);
  }

  get #uncategorized() {
    return (
      this.args.uncategorized ??
      (this.multiple || this.siteSettings.allow_uncategorized_topics)
    );
  }

  get placeholder() {
    // The fallback ports the single chooser's empty header; multiple pickers keep the select's own.
    if (this.args.placeholder || this.multiple) {
      return this.args.placeholder;
    }
    return (
      (!this.#readOnly.length && this.#uncategorized
        ? Category.findUncategorized()?.name
        : undefined) || decodeCategoryText(i18n("category.choose"))
    );
  }

  get loadContext() {
    return {
      heldExcluded: this.#heldExcludedKey,
      permission: this.args.permission,
      scope: this.args.scope,
      prioritize: this.args.prioritize,
      exclude: this.args.exclude,
      readOnly: this.args.readOnly,
      uncategorized: this.#uncategorized,
      subcategories: this.args.subcategories,
      descriptions: this.args.descriptions,
      multiple: this.multiple,
      selectDescendants: this.args.selectDescendants,
      lazy: this.site.lazy_load_categories,
      categories: this.site.lazy_load_categories
        ? undefined
        : this.site.sortedCategories,
      fixed: this.siteSettings.fixed_category_positions_on_create,
    };
  }

  @action
  load(query: string, opts: SelectLoadOptions) {
    if (this.site.lazy_load_categories) {
      return this.#loadPage(query, opts);
    }
    let categories: CategoryRecord[] = this.siteSettings
      .fixed_category_positions_on_create
      ? Category.sortCategories(this.site.categories)
      : this.site.sortedCategories;
    const family = this.#localFamily(this.args.scope ?? this.args.prioritize);
    const allowed = this.#categoryAllowed();
    const readOnly = new Set(this.#readOnly);
    const term = normalizeCategoryName(query);
    const multiple = this.multiple;
    categories = categories.filter(
      (category) =>
        allowed(category) &&
        (!query || this.#matches(category, term, multiple)) &&
        (query ||
          !this.args.scope ||
          !family ||
          this.#inFamily(category, family) ||
          readOnly.has(category.id))
    );
    if (!query && this.args.prioritize && family && !this.args.scope) {
      const prioritized: CategoryRecord[] = [];
      const rest: CategoryRecord[] = [];
      for (const category of categories) {
        const target = this.#inFamily(category, family) ? prioritized : rest;
        target.push(category);
      }
      categories = prioritized.concat(rest);
    }
    const offset = opts.offset ?? 0;
    const { items, total } = this.#rows(categories, query, offset, 32);
    return {
      items,
      total,
      hasMore: offset + items.length < total,
    };
  }

  @action
  async resolveValues(values: unknown[], opts: SelectLoadOptions) {
    const records = await resolveCategories(
      values.filter(
        (id): id is string | number =>
          typeof id === "number" || typeof id === "string"
      )
    );
    opts.signal?.throwIfAborted();
    return records.map((category) => categoryItem(category));
  }

  @action
  specialItems(snapshot: SelectSnapshot): CategoryItem[] {
    return this.multiple && this.args.noneLabel && !snapshot.filter
      ? [
          {
            id: "category-none",
            name: this.args.noneLabel,
            onSelect: (control) => control.clear(),
          },
        ]
      : [];
  }

  @action
  onChange(value: SelectValue) {
    let ids: (number | string)[] = [];
    if (Array.isArray(value)) {
      ids = value as (number | string)[];
    } else if (typeof value === "number" || typeof value === "string") {
      ids = [value];
    }
    const result = this.args.emit === "ids" ? ids : knownCategories(ids);
    this.args.onChange?.(this.multiple ? result : (result[0] ?? null));
  }

  #categoryAllowed() {
    const readOnly = new Set(this.#readOnly);
    const excluded = new Set((this.args.exclude ?? []).map(Number));
    const held = new Set(this._ids);
    const onlyPostable = this.args.permission === "create";
    const uncategorized = this.#uncategorized;
    const uncategorizedId = this.site.uncategorized_category_id;
    const subcategories = this.args.subcategories !== false;
    return (category: CategoryRecord) =>
      readOnly.has(category.id) ||
      ((!onlyPostable || category.permission === 1) &&
        (uncategorized || category.id !== uncategorizedId) &&
        (subcategories || !category.parent_category_id) &&
        (!excluded.has(category.id) || held.has(category.id)));
  }

  #matches(category: CategoryRecord, term: string, multiple = this.multiple) {
    if (normalizeCategoryName(category.name).includes(term)) {
      return true;
    }
    return (
      !multiple &&
      !!category.parentCategory &&
      normalizeCategoryName(category.parentCategory.name).includes(term)
    );
  }

  #categoryKeys(value?: CategoryValue): (number | string)[] {
    if (value == null) {
      return [];
    }
    return [typeof value === "object" ? value.id : value];
  }

  #localFamily(value?: CategoryValue): number | undefined {
    const category = knownCategories(this.#categoryKeys(value))[0];
    return category?.parent_category_id || category?.id;
  }

  #inFamily(category: CategoryRecord, id: number) {
    return category.id === id || category.parent_category_id === id;
  }

  #rows(
    categories: CategoryRecord[],
    query: string,
    offset = 0,
    limit = Infinity
  ) {
    const descendantsEnabled =
      query.length >= 2 &&
      this.multiple &&
      this.args.selectDescendants !== false;
    const byParent = descendantsEnabled
      ? this.site.categoriesByParentId
      : undefined;
    const readOnly = new Set(this.#readOnly);
    const descriptions = this.args.descriptions ?? !this.multiple;
    const readOnlyDescription = i18n("category_row.read_only_description");
    const items: CategoryItem[] = [];
    let total = 0;
    for (const category of categories) {
      const isReadOnly = readOnly.has(category.id);
      const withDescendants =
        descendantsEnabled &&
        !isReadOnly &&
        (category.has_children || byParent?.has(category.id));
      const position = total;
      total += withDescendants ? 2 : 1;
      if (position >= offset && position < offset + limit) {
        const row = categoryItem(category, descriptions);
        row.disabled = isReadOnly;
        row.description = isReadOnly ? readOnlyDescription : row.description;
        items.push(row);
      }
      if (
        !withDescendants ||
        position + 1 < offset ||
        position + 1 >= offset + limit
      ) {
        continue;
      }
      items.push({
        id: `category-descendants-${category.id}`,
        name: i18n("category.select_with_subcategories", {
          category: category.name,
        }),
        category,
        onSelect: (control) => {
          void control.update(async (scope) => {
            let descendants: CategoryRecord[];
            try {
              descendants = await loadDescendants(category, {
                signal: scope.signal,
              });
            } catch (error) {
              if (scope.signal.aborted) {
                return;
              }
              throw error;
            }
            const allowed = this.#categoryAllowed();
            const excluded = new Set((this.args.exclude ?? []).map(Number));
            const locked = new Set(this.#readOnly);
            scope.selectMany(
              descendants
                .filter(
                  (child) =>
                    !excluded.has(child.id) &&
                    !locked.has(child.id) &&
                    allowed(child)
                )
                .map((child) => categoryItem(child))
            );
          });
        },
      });
    }
    return { items, total };
  }

  async #loadPage(query: string, opts: SelectLoadOptions) {
    const first = !opts.offset;
    const [scope, prioritize, readOnly] = await Promise.all([
      resolveCategories(this.#categoryKeys(this.args.scope)),
      resolveCategories(this.#categoryKeys(this.args.prioritize)),
      resolveCategories(this.#readOnly),
    ]);
    opts.signal?.throwIfAborted();
    const scopeId =
      !query && scope[0]
        ? scope[0].parent_category_id || scope[0].id
        : undefined;
    const prioritizeId =
      !query && prioritize[0]
        ? prioritize[0].parent_category_id || prioritize[0].id
        : undefined;
    const result = await fetchCategoryPage({
      term: query,
      cursor: opts.cursor ?? null,
      parentCategoryId: scopeId,
      prioritizedId: prioritizeId,
      rejectIds: [
        ...new Set([
          ...(this.args.exclude ?? [])
            .map(Number)
            .filter((id) => !this._ids.includes(id)),
          ...this.#readOnly,
        ]),
      ],
      includeUncategorized: this.#uncategorized,
      includeSubcategories: this.args.subcategories !== false,
      onlyPostable: this.args.permission === "create",
      signal: opts.signal,
    });
    const extras: CategoryRecord[] = [];
    if (scopeId) {
      extras.push(...(await resolveCategories([scopeId])));
    }
    extras.push(
      ...readOnly.filter(
        (category) =>
          !query || this.#matches(category, normalizeCategoryName(query))
      )
    );
    opts.signal?.throwIfAborted();
    const allowed = this.#categoryAllowed();
    const injected = extras.filter(
      (category, index) =>
        extras.findIndex((other) => other.id === category.id) === index &&
        allowed(category)
    );
    const categories = [
      ...(first ? injected : []),
      ...result.categories,
    ].filter(
      (category, index, all) =>
        all.findIndex((other) => other.id === category.id) === index &&
        allowed(category)
    );
    const hasMore = result.hasMore;
    return {
      items: this.#rows(categories, query).items,
      cursor: result.cursor,
      hasMore,
      total:
        hasMore &&
        !(
          this.multiple &&
          query.length >= 2 &&
          this.args.selectDescendants !== false
        )
          ? result.total + injected.length
          : undefined,
    };
  }

  <template>
    <DSelect
      ...attributes
      @clearable={{@clearable}}
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
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
      @multiple={{this.multiple}}
      @noneLabel={{@noneLabel}}
      @onChange={{this.onChange}}
      @onClose={{@onClose}}
      @placeholder={{this.placeholder}}
      @resolveValues={{this.resolveValues}}
      @specialItems={{this.specialItems}}
      @suppressFooter={{not (has-block "footer")}}
      @value={{this.value}}
      @variant={{@variant}}
    >
      <:item as |item options|>
        {{#if (has-block "item")}}
          {{yield item options to="item"}}
        {{else}}
          <CategoryBadge @ancestors={{true}} @counts={{true}} @item={{item}} />
        {{/if}}
      </:item>
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
