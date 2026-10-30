import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import {
  cleanTagName,
  searchTags,
  sortTagRows,
  topTags,
} from "discourse/lib/tag-source";
import type Site from "discourse/models/site";
import type SiteSettingsService from "discourse/services/site-settings";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import DSelect from "discourse/ui-kit/select/d-select";
import SelectTagBase, {
  TAG_TEXTS,
} from "discourse/ui-kit/select/recipes/tags/-internals/select-tag-base";
import {
  tagItemName,
  TagOption,
  TagSelection,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-renderers";
import type { TagObject } from "discourse/ui-kit/select/recipes/tags/-internals/tag-values";
import {
  renderSelectText,
  type SelectItem,
  type SelectKindTexts,
  type SelectLoadOptions,
  type SelectResolvedOptions,
  type SelectSnapshot,
  type SelectTexts,
  type SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** Shortcut for clearing a tag filter. */
export const ALL_TAGS_ID = "all-tags";

/** Shortcut for topics without tags. */
export const NO_TAG_ID = "no-tags";

/** Tag filter rows may use names as keys in a call-site source. */
type FilterTag = SelectItem & {
  id: number | string;
  name: string;
  slug?: string;
  target_tag?: FilterTag;
};

/**
 * The filter's texts. Both modes declare them, so a customization for the kind applies whatever
 * `@multiple` is.
 */
const FILTER_TEXTS: SelectTexts = Object.freeze({
  ariaLabel: { key: "tagging.filter_by_tags_label" },
  placeholder: { key: "tagging.selector_tags" },
  removeFilter: { key: "tagging.selector_remove_filter" },
  noTags: { key: "tagging.selector_no_tags" },
  filterForMore: { key: "select_kit.components.filter_for_more" },
});

/** Engine blocks and source overrides shared with callers. */
type SelectSignature =
  DSelect extends Component<infer Signature> ? Signature : never;

/** A topic-list filter that leaves navigation to its caller. */
interface DSelectTagFilterSignature {
  Args: {
    /** Current tag or shortcut, where none or `ALL_TAGS_ID` filters nothing; multiple mode holds tags in order. */
    value?:
      | TagObject
      | readonly TagObject[]
      | typeof ALL_TAGS_ID
      | typeof NO_TAG_ID
      | null;
    /** Select several tags for an intersection; defaults to false. */
    multiple?: boolean;
    /** Category limiting the available tags. */
    categoryId?: number;
    /** Temporary compatibility aliases for legacy customizations and CSS. */
    legacyKind?: SelectSignature["Args"]["legacyKind"];
    /** Local tags replacing the site's top tags and server search. */
    items?: readonly FilterTag[];
    /** Optional asynchronous source override. */
    load?: SelectSignature["Args"]["load"];
    /** Receives a full tag row, a shortcut id, or the ordered held tags in multiple mode. */
    onChange?: (
      value: TagObject | TagObject[] | typeof ALL_TAGS_ID | typeof NO_TAG_ID
    ) => void;
    /** Call-site customization identity. */
    identifier?: string;
    /** Call-site state exposed to customizations. */
    instanceContext?: object;
    /**
     * The filter's texts, over its defaults: `removeFilter` and `noTags` name the shortcuts, and
     * `filterForMore` hints that a search finds tags beyond the listed ones.
     */
    texts?: SelectSignature["Args"]["texts"];
    /** Prevent opening or selecting. */
    disabled?: boolean;
  };
  Element: HTMLElement;
  Blocks: Pick<SelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/** Selects tags for a topic list without navigating. */
export default class DSelectTagFilter extends Component<DSelectTagFilterSignature> {
  /** TODO(typescript-pending): Remove the extension when Site declares serialized top tags. */
  @service
  declare site: Site & {
    top_tags?: FilterTag[];
    category_top_tags?: FilterTag[];
  };

  /** TODO(typescript-pending): Remove the extension when the settings factory exposes runtime keys. */
  @service
  declare siteSettings: SiteSettingsService & {
    max_tags_in_filter_list: number;
    max_tag_search_results: number;
    tags_sort_alphabetically: boolean;
    max_tags_per_topic: number;
    max_tag_length: number;
    force_lowercase_tags: boolean;
  };

  @tracked moreTags = false;

  /** The single drop's texts; it draws tag rows too, so it declares the tag texts as well. */
  kindTexts: SelectKindTexts = [TAG_TEXTS, FILTER_TEXTS];

  /** The intersection filter's texts, above the tag field's. */
  multipleKindTexts = FILTER_TEXTS;

  constructor(owner: Owner, args: DSelectTagFilterSignature["Args"]) {
    super(owner, args);
    assertNoRemovedTextArgs("DSelectTagFilter", args);
  }

  get legacyKind() {
    return (
      this.args.legacyKind ??
      (this.args.multiple
        ? ["tags-intersection-chooser", "mini-tag-chooser"]
        : "tag-drop")
    );
  }

  /** The legacy tag class, plus `--filtering` while the filter narrows the list. */
  get rootClass() {
    const tag = this.#tag;
    const tagClass =
      tag && "slug" in tag && tag.slug ? `tag-${tag.slug}` : "tag_all";
    return this.heldId !== undefined ? `${tagClass} --filtering` : tagClass;
  }

  get #tag(): FilterTag | undefined {
    const value = this.args.value;
    return value && !Array.isArray(value) && typeof value === "object"
      ? (value as FilterTag)
      : undefined;
  }

  /** The held filter. With no tag, or the "all tags" shortcut, it holds nothing, so the placeholder shows. */
  get heldId(): number | string | undefined {
    const tag = this.#tag;
    if (
      this.args.value === NO_TAG_ID ||
      tag?.name === "none" ||
      tag?.name === NO_TAG_ID
    ) {
      return NO_TAG_ID;
    }
    return tag?.id || undefined;
  }

  get localItems() {
    return this.args.items ? [...this.args.items] : undefined;
  }

  get multipleValue() {
    return Array.isArray(this.args.value) ? this.args.value : [];
  }

  get loadContext() {
    return {
      categoryId: this.args.categoryId,
      items: this.args.items,
    };
  }

  /** The held filter's row, built from the options so a customized shortcut name reaches it. */
  @action
  valueItems(options: SelectResolvedOptions): SelectItem[] {
    const id = this.heldId;
    if (id === NO_TAG_ID) {
      return [{ id, name: renderSelectText(options, "noTags") }];
    }
    // A tag model keeps its fields on getters, which a spread would drop.
    return id === undefined ? [] : [this.#tag!];
  }

  isShortcut(item: SelectItem) {
    return item.id === ALL_TAGS_ID || item.id === NO_TAG_ID;
  }

  @action
  async load(filter: string, opts: SelectLoadOptions): Promise<SelectItem[]> {
    if (filter && !this.args.items) {
      const result = await searchTags(filter, {
        context: { everyTag: true, categoryId: this.args.categoryId },
        signal: opts.signal,
        siteSettings: this.siteSettings,
      });
      this.moreTags =
        result.items.length > this.siteSettings.max_tags_in_filter_list;
      return result.items.map((tag) => ({ ...tag }));
    }
    const tags =
      this.args.items ??
      topTags<FilterTag>({
        site: this.site,
        categoryId: this.args.categoryId,
      });
    const term = filter.toLowerCase();
    const matches = term
      ? tags.filter((tag) => tag.name.toLowerCase().includes(term))
      : [...tags];
    this.moreTags =
      !filter && tags.length > this.siteSettings.max_tags_in_filter_list;
    return sortTagRows(
      matches.slice(0, this.siteSettings.max_tags_in_filter_list),
      {
        alphabetical: this.siteSettings.tags_sort_alphabetically,
        exact: cleanTagName(filter, this.siteSettings),
      }
    );
  }

  /** The shortcuts lead browsing and are left out of searches. */
  @action
  specialItems(
    snapshot: SelectSnapshot,
    options: SelectResolvedOptions
  ): SelectItem[] {
    if (snapshot.filter) {
      return [];
    }
    const shortcuts: SelectItem[] = [];
    const held = this.heldId;
    if (held !== undefined) {
      shortcuts.push({
        id: ALL_TAGS_ID,
        name: renderSelectText(options, "removeFilter"),
      });
    }
    if (held !== NO_TAG_ID) {
      shortcuts.push({
        id: NO_TAG_ID,
        name: renderSelectText(options, "noTags"),
      });
    }
    return shortcuts;
  }

  @action
  onChange(id: SelectValue, item: SelectItem | SelectItem[] | null) {
    // A null id is DSelect's keyboard clear; a filter only clears through its "All tags" row.
    if (
      (typeof id !== "string" && typeof id !== "number") ||
      !item ||
      Array.isArray(item) ||
      typeof item.name !== "string"
    ) {
      return;
    }
    this.args.onChange?.(
      id === ALL_TAGS_ID || id === NO_TAG_ID
        ? id
        : { ...item, id, name: item.name }
    );
  }

  @action
  onMultipleChange(tags: TagObject[] | TagObject | string[] | string | null) {
    if (Array.isArray(tags)) {
      this.args.onChange?.(tags as TagObject[]);
    }
  }

  <template>
    {{#if @multiple}}
      <SelectTagBase
        ...attributes
        @categoryId={{@categoryId}}
        @disabled={{@disabled}}
        @identifier={{@identifier}}
        @instanceContext={{@instanceContext}}
        @items={{this.localItems}}
        @kind="select-tag-filter"
        @kindContext={{hash value=@value categoryId=@categoryId}}
        @kindTexts={{this.multipleKindTexts}}
        @legacyKind={{this.legacyKind}}
        @load={{@load}}
        @multiple={{true}}
        @onChange={{this.onMultipleChange}}
        @requirementPlaceholders={{false}}
        @suppressFooter={{not (has-block "footer")}}
        @texts={{@texts}}
        @value={{this.multipleValue}}
      >
        <:item as |item options|>
          {{#if (has-block "item")}}
            {{yield item options to="item"}}
          {{else}}
            <TagOption @item={{item}} @options={{options}} />
          {{/if}}
        </:item>
        <:selection as |item options|>
          {{#if (has-block "selection")}}
            {{yield item options to="selection"}}
          {{else}}
            <TagSelection @item={{item}} />
          {{/if}}
        </:selection>
        <:footer as |state options|>
          {{yield state options to="footer"}}
        </:footer>
      </SelectTagBase>
    {{else}}
      {{! TODO (select-kit-replacement-cleanup): Retain the legacy family and filter classes during rollout. }}
      <DSelect
        class={{this.rootClass}}
        ...attributes
        @caretIcon={{hash closed="angle-right" open="angle-down"}}
        @disabled={{@disabled}}
        @identifier={{@identifier}}
        @instanceContext={{@instanceContext}}
        @kind="select-tag-filter"
        @kindContext={{hash value=@value categoryId=@categoryId}}
        @kindTexts={{this.kindTexts}}
        @labelField="name"
        @legacyKind={{this.legacyKind}}
        @load={{if @load @load this.load}}
        @loadContext={{this.loadContext}}
        @onChange={{this.onChange}}
        @searchIcon="magnifying-glass"
        @specialItems={{this.specialItems}}
        @suppressFooter={{not (or (has-block "footer") this.moreTags)}}
        @texts={{@texts}}
        @value={{this.heldId}}
        @valueItems={{this.valueItems}}
        @variant="button"
      >
        <:item as |item options|>
          {{#if (has-block "item")}}
            {{yield item options to="item"}}
          {{else if (this.isShortcut item)}}
            <span class="d-tag-drop__shortcut">{{tagItemName item}}</span>
          {{else}}
            <TagOption @item={{item}} @options={{options}} />
          {{/if}}
        </:item>
        <:selection as |item options|>
          {{#if (has-block "selection")}}
            {{yield item options to="selection"}}
          {{else}}
            <span class="d-tag-drop__selection">
              {{~! no whitespace around the tag ~}}
              <TagSelection @item={{item}} />
            </span>
          {{/if}}
        </:selection>
        <:footer as |state options|>
          {{#if (has-block "footer")}}
            {{yield state options to="footer"}}
          {{else if this.moreTags}}
            {{#let (renderSelectText options "filterForMore") as |hint|}}
              {{#if hint}}
                <span class="d-tag-drop__filter-for-more">
                  {{~hint~}}
                </span>
              {{/if}}
            {{/let}}
          {{/if}}
        </:footer>
      </DSelect>
    {{/if}}
  </template>
}
