import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { searchTags, sortTagRows, topTags } from "discourse/lib/tag-source";
import type Site from "discourse/models/site";
import type SiteSettingsService from "discourse/services/site-settings";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import type { SelectResolvedOptions } from "discourse/ui-kit/select/-internals/engine/customizations";
import DSelect from "discourse/ui-kit/select/d-select";
import SelectTagBase from "discourse/ui-kit/select/recipes/tags/-internals/select-tag-base";
import {
  tagItemName,
  TagOption,
  TagSelection,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-select-base";
import type { TagObject } from "discourse/ui-kit/select/recipes/tags/-internals/tag-values";
import type {
  SelectItem,
  SelectLoadOptions,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

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

/** Engine blocks and source overrides shared with callers. */
type SelectSignature =
  DSelect extends Component<infer Signature> ? Signature : never;

/** A topic-list filter that leaves navigation to its caller. */
interface DSelectTagFilterSignature {
  Args: {
    /** Current tag or shortcut; multiple mode holds tags in order. */
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
    /** Accessible control label. */
    label?: string;
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
  };

  @tracked expanded = false;
  @tracked moreTags = false;

  get multiple() {
    return this.args.multiple === true;
  }

  get legacyKind() {
    return (
      this.args.legacyKind ??
      (this.multiple
        ? ["tags-intersection-chooser", "mini-tag-chooser"]
        : "tag-drop")
    );
  }

  get tagClass() {
    const tag = this.#tag;
    return tag && "slug" in tag && tag.slug ? `tag-${tag.slug}` : "tag_all";
  }

  get #tag(): TagObject | undefined {
    const value = this.args.value;
    return value && !Array.isArray(value) && typeof value === "object"
      ? (value as TagObject)
      : undefined;
  }

  get selection() {
    const tag = this.#tag;
    if (
      this.args.value === NO_TAG_ID ||
      tag?.name === "none" ||
      tag?.name === NO_TAG_ID
    ) {
      return { id: NO_TAG_ID, name: i18n("tagging.selector_no_tags") };
    }
    return tag?.id
      ? { ...tag, id: tag.id }
      : { id: ALL_TAGS_ID, name: i18n("tagging.selector_tags") };
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
      value: this.args.value,
    };
  }

  isShortcut(item: SelectItem) {
    return item.id === ALL_TAGS_ID || item.id === NO_TAG_ID;
  }

  @action
  caret(options: SelectResolvedOptions) {
    const icon = this.expanded ? options.caretUpIcon : options.caretDownIcon;
    return typeof icon === "string"
      ? icon
      : this.expanded
        ? "angle-down"
        : "angle-right";
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
    const tags = [
      ...(this.args.items ??
        topTags<FilterTag>({
          site: this.site,
          categoryId: this.args.categoryId,
        })),
    ];
    this.moreTags =
      !filter && tags.length > this.siteSettings.max_tags_in_filter_list;
    const shortcuts: FilterTag[] = [];
    if (this.selection.id !== ALL_TAGS_ID) {
      shortcuts.push({
        id: ALL_TAGS_ID,
        name: i18n("tagging.selector_remove_filter"),
      });
    }
    if (this.selection.id !== NO_TAG_ID) {
      shortcuts.push({ id: NO_TAG_ID, name: i18n("tagging.selector_no_tags") });
    }
    return [
      ...shortcuts,
      ...sortTagRows(
        (filter
          ? tags.filter((tag) =>
              tag.name.toLowerCase().includes(filter.toLowerCase())
            )
          : tags
        ).slice(0, this.siteSettings.max_tags_in_filter_list),
        {
          alphabetical: this.siteSettings.tags_sort_alphabetically,
        }
      ),
    ].filter(
      (tag) => !filter || tag.name.toLowerCase().includes(filter.toLowerCase())
    );
  }

  @action
  onChange(id: SelectValue, item: SelectItem | SelectItem[] | null) {
    if (id === null) {
      this.args.onChange?.(ALL_TAGS_ID);
      return;
    }
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

  @action
  onShow() {
    this.expanded = true;
  }

  @action
  onClose() {
    this.expanded = false;
  }

  <template>
    {{#if this.multiple}}
      <SelectTagBase
        ...attributes
        @categoryId={{@categoryId}}
        @disabled={{@disabled}}
        @identifier={{@identifier}}
        @instanceContext={{@instanceContext}}
        @items={{this.localItems}}
        @kind="select-tag-filter"
        @kindContext={{hash value=@value categoryId=@categoryId}}
        @label={{@label}}
        @legacyKind={{this.legacyKind}}
        @load={{@load}}
        @multiple={{true}}
        @onChange={{this.onMultipleChange}}
        @value={{this.multipleValue}}
      >
        <:item as |item options|>
          {{#if (has-block "item")}}
            {{yield item options to="item"}}
          {{else}}
            <TagOption @item={{item}} />
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
        class={{this.tagClass}}
        ...attributes
        @disabled={{@disabled}}
        @identifier={{@identifier}}
        @instanceContext={{@instanceContext}}
        @kind="select-tag-filter"
        @kindContext={{hash value=@value categoryId=@categoryId}}
        @kindOptions={{hash
          caretDownIcon="angle-right"
          caretUpIcon="angle-down"
        }}
        @label={{if @label @label (i18n "tagging.selector_tags")}}
        @labelField="name"
        @legacyKind={{this.legacyKind}}
        @load={{if @load @load this.load}}
        @loadContext={{this.loadContext}}
        @onChange={{this.onChange}}
        @onClose={{this.onClose}}
        @onShow={{this.onShow}}
        @showCaret={{false}}
        @value={{this.selection.id}}
        @valueItems={{this.selection}}
        @variant="button"
      >
        <:item as |item options|>
          {{#if (has-block "item")}}
            {{yield item options to="item"}}
          {{else if (this.isShortcut item)}}
            <span class="d-tag-drop__shortcut">{{tagItemName item}}</span>
          {{else}}
            <TagOption @item={{item}} />
          {{/if}}
        </:item>
        <:selection as |item options|>
          {{#if (has-block "selection")}}
            {{yield item options to="selection"}}
          {{else}}
            <span class="d-tag-drop__selection">
              {{~! no whitespace around the tag and its caret ~}}
              <TagSelection @item={{item}} />
              {{~dIcon (this.caret options)~}}
            </span>
          {{/if}}
        </:selection>
        <:footer as |state options|>
          {{#if (has-block "footer")}}
            {{yield state options to="footer"}}
          {{else if this.moreTags}}
            <span class="d-tag-drop__filter-for-more">
              {{~i18n "select_kit.components.filter_for_more"~}}
            </span>
          {{/if}}
        </:footer>
      </DSelect>
    {{/if}}
  </template>
}
