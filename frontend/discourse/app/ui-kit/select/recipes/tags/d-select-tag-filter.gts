import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import {
  cleanTagName,
  searchTags,
  sortTagRows,
  storedName,
  tagSettings,
  topTags,
} from "discourse/lib/tag-source";
import type Site from "discourse/models/site";
import type SiteSettingsService from "discourse/services/site-settings";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import DSelect, {
  type DSelectSignature,
} from "discourse/ui-kit/select/d-select";
import type { MultiSelectRecipeArgs } from "discourse/ui-kit/select/recipes/-internals/recipe-args";
import {
  TagOption,
  tagRecordName,
  TagSelection,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-renderers";
import {
  type SelectTagTextKey,
  TAG_TEXTS,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-texts";
import type { TagObject } from "discourse/ui-kit/select/recipes/tags/-internals/tag-values";
import {
  renderSelectText,
  type SelectConfig,
  type SelectOption,
  selectOption,
  type SelectOptionLike,
  type SelectRecord,
  type SelectSnapshot,
  type SelectTexts,
  type SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** Shortcut for clearing a tag filter. */
export const ALL_TAGS_ID = "all-tags";

/** Shortcut for topics without tags. */
export const NO_TAG_ID = "no-tags";

/** Tag filter rows may use names as keys in a call-site source. */
type FilterTag = SelectRecord & {
  id: number | string;
  name: string;
  slug?: string;
  target_tag?: FilterTag;
};

/** The single filter's caret, pointing right while closed. */
const DROP_CARET = Object.freeze({ closed: "angle-right", open: "angle-down" });

/** A held tag's or a row's key while the filter holds several: its stored name, in lowercase. */
function nameKey(tag: { name: string; original_name?: string }) {
  return storedName(tag).toLowerCase();
}

/** A topic-list filter that leaves navigation to its caller. */
interface DSelectTagFilterSignature {
  Args: Omit<MultiSelectRecipeArgs, "lockedValues"> & {
    /**
     * Current tag or shortcut, where none or `ALL_TAGS_ID` filters nothing; with `@multiple`, the
     * held tags in order, by id or by name.
     */
    value?:
      | TagObject
      | readonly TagObject[]
      | typeof ALL_TAGS_ID
      | typeof NO_TAG_ID
      | null;
    /** Holds several tags, for an intersection; defaults to one. */
    multiple?: boolean;
    /** With `@multiple`, held tags that can't be removed, by name or as held. */
    lockedValues?: readonly (TagObject | string)[];
    /** Visible chip limit; zero shows only the selection count. */
    maxVisibleChips?: number;
    /** Category limiting the available tags. */
    categoryId?: number;
    /** Local tags, as records or options, replacing the site's top tags and server search. */
    options?: readonly SelectOptionLike<FilterTag>[];
    /** Receives a full tag row or a shortcut id; with `@multiple`, the held tags in order. */
    onChange?: (
      value: TagObject | TagObject[] | typeof ALL_TAGS_ID | typeof NO_TAG_ID
    ) => void;
    /**
     * The filter's texts, over its defaults: `removeFilter` and `noTags` name the shortcuts, and
     * `maxLoaded` says to keep typing when the top tags outnumber the list.
     */
    texts?: SelectTexts<SelectTagTextKey | "removeFilter" | "noTags">;
    /** Prevent opening or selecting. */
    disabled?: boolean;
    /** Ids of visible captions that name the control, replacing "Filter by: tags". */
    ariaLabelledBy?: string;
  };
  Element: HTMLElement;
  Blocks: Pick<DSelectSignature["Blocks"], "option" | "selection" | "footer">;
}

/** Selects a tag, a shortcut or, with `@multiple`, several tags for a topic list without navigating. */
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

  /**
   * The filter's texts, over the tag texts it draws its rows with. Both modes declare them, so a
   * customization for the kind applies whatever `@multiple` is.
   */
  kindTexts: SelectTexts = {
    ...TAG_TEXTS,
    ariaLabel: i18n("tagging.filter_by_tags_label"),
    placeholder: i18n("tagging.selector_tags"),
    removeFilter: i18n("tagging.selector_remove_filter"),
    noTags: i18n("tagging.selector_no_tags"),
    maxLoaded: i18n("tagging.filter_to_narrow_tags"),
  };

  constructor(owner: Owner, args: DSelectTagFilterSignature["Args"]) {
    super(owner, args);
    assertNoRemovedTextArgs("DSelectTagFilter", args);
  }

  get legacyKind() {
    if (this.args.legacyKind) {
      return this.args.legacyKind;
    }
    return this.args.multiple
      ? ["tags-intersection-chooser", "mini-tag-chooser"]
      : "tag-drop";
  }

  /** The legacy tag class, plus `--filtering` while the filter narrows the list. */
  get rootClass() {
    if (this.args.multiple) {
      return undefined;
    }
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

  get #heldTags(): readonly TagObject[] {
    return Array.isArray(this.args.value) ? this.args.value : [];
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

  get selection() {
    return this.args.multiple
      ? this.#heldTags.map((tag) => nameKey(tag))
      : this.heldId;
  }

  /** The locked tags as the engine holds them: their name keys. */
  get lockedKeys() {
    return this.args.lockedValues?.map((tag) =>
      typeof tag === "string" ? tag.toLowerCase() : nameKey(tag)
    );
  }

  /** Several held tags are matched to rows by name, because a URL holds them by name. */
  get valueField() {
    return this.args.multiple ? "nameKey" : "id";
  }

  get caretIcon() {
    return this.args.multiple ? undefined : DROP_CARET;
  }

  get variant() {
    return this.args.multiple ? undefined : "button";
  }

  /**
   * The caller's records and what their settings say, compared by value, so options rebuilt
   * the same don't reload and a changed setting does.
   */
  get loadContext() {
    const options = this.args.options?.map((entry) => selectOption(entry));
    return {
      categoryId: this.args.categoryId,
      records: options?.map((option) => option.record),
      settings: options?.map((option) =>
        JSON.stringify([
          option.disabled,
          option.description ?? null,
          option.position ?? null,
          option.divider ?? null,
          option.action,
        ])
      ),
    };
  }

  /** The held filter's row, built from the options so a customized shortcut name reaches it. */
  @action
  valueRecords(config: SelectConfig): SelectRecord[] {
    if (this.args.multiple) {
      // A tag model keeps its fields on getters, which a spread would drop.
      return this.#heldTags.map((tag) => ({
        id: tag.id,
        name: tag.name,
        slug: (tag as FilterTag).slug,
        nameKey: nameKey(tag),
      }));
    }
    const id = this.heldId;
    if (id === NO_TAG_ID) {
      return [{ id, name: renderSelectText(config, "noTags") }];
    }
    // A tag model keeps its fields on getters, which a spread would drop.
    return id === undefined ? [] : [this.#tag!];
  }

  isShortcut(record: SelectRecord) {
    return record.id === ALL_TAGS_ID || record.id === NO_TAG_ID;
  }

  @action
  async load(filter: string) {
    if (filter && !this.args.options) {
      const result = await searchTags(filter, {
        context: { everyTag: true, categoryId: this.args.categoryId },
        siteSettings: this.siteSettings,
      });
      return result.items.map((row) => this.#option(row, tagSettings(row)));
    }
    // A tag shows its description; the caller's own settings come on top.
    const options =
      this.args.options?.map((entry) => {
        const option = selectOption(entry);
        return option.with({
          description: tagSettings(option.record).description,
          ...option.settings,
        });
      }) ??
      topTags<FilterTag>({
        site: this.site,
        categoryId: this.args.categoryId,
      }).map((tag) => selectOption(tag, tagSettings(tag)));
    const term = filter.toLowerCase();
    const matches = term
      ? options.filter(({ record }) => record.name.toLowerCase().includes(term))
      : options;
    // Sorted by the option, so a caller's disabled option sorts last like a refused row.
    const sorted = sortTagRows(
      matches.map((option) => ({
        name: option.record.name,
        original_name:
          typeof option.record.original_name === "string"
            ? option.record.original_name
            : undefined,
        disabled: option.disabled,
        option,
      })),
      {
        alphabetical: this.siteSettings.tags_sort_alphabetically,
        exact: cleanTagName(filter, this.siteSettings),
      }
    );
    return sorted.map(({ option }) =>
      this.#option(option.record, option.settings)
    );
  }

  /** The shortcuts lead browsing and are left out of searches. */
  @action
  extraOptions(snapshot: SelectSnapshot, config: SelectConfig): SelectRecord[] {
    if (snapshot.filter || this.args.multiple) {
      return [];
    }
    const shortcuts: SelectRecord[] = [];
    const held = this.heldId;
    if (held !== undefined) {
      shortcuts.push({
        id: ALL_TAGS_ID,
        name: renderSelectText(config, "removeFilter"),
      });
    }
    if (held !== NO_TAG_ID) {
      shortcuts.push({
        id: NO_TAG_ID,
        name: renderSelectText(config, "noTags"),
      });
    }
    return shortcuts;
  }

  @action
  onChange(id: SelectValue, record: SelectRecord | SelectRecord[] | null) {
    if (this.args.multiple) {
      this.#onMultipleChange(record);
      return;
    }
    // A null id is DSelect's keyboard clear; a filter only clears through its "All tags" row.
    if (
      (typeof id !== "string" && typeof id !== "number") ||
      !record ||
      Array.isArray(record) ||
      typeof record.name !== "string"
    ) {
      return;
    }
    this.args.onChange?.(
      id === ALL_TAGS_ID || id === NO_TAG_ID
        ? id
        : { ...record, id, name: record.name }
    );
  }

  /** Held tags keep their identity; new picks are emitted as their rows. */
  #onMultipleChange(records: SelectRecord | SelectRecord[] | null) {
    const held = new Map(this.#heldTags.map((tag) => [nameKey(tag), tag]));
    const tags = (Array.isArray(records) ? records : []).map((record) => {
      const { nameKey: key, ...row } = record;
      return held.get(key as string) ?? (row as unknown as TagObject);
    });
    this.args.onChange?.(tags);
  }

  /**
   * A tag as the filter lists it. Holding several tags keys them by name, so that projection is
   * the filter's own record, carrying the tag's settings.
   */
  #option(
    tag: { name: string; original_name?: string },
    settings: SelectOption["settings"]
  ): SelectOption {
    return selectOption(
      this.args.multiple ? { ...tag, nameKey: nameKey(tag) } : tag,
      settings
    );
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Retain the legacy family and filter classes during rollout. }}
    <DSelect
      class={{this.rootClass}}
      ...attributes
      @ariaLabelledBy={{@ariaLabelledBy}}
      @caretIcon={{this.caretIcon}}
      @disabled={{@disabled}}
      @extraOptions={{this.extraOptions}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @kind="select-tag-filter"
      @kindContext={{hash value=@value categoryId=@categoryId}}
      @kindTexts={{this.kindTexts}}
      @labelField="name"
      @legacyKind={{this.legacyKind}}
      @load={{this.load}}
      @loadContext={{this.loadContext}}
      @lockedValues={{this.lockedKeys}}
      @maxLoaded={{this.siteSettings.max_tags_in_filter_list}}
      @maxVisibleChips={{@maxVisibleChips}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @searchIcon="magnifying-glass"
      @suppressFooter={{not (has-block "footer")}}
      @texts={{@texts}}
      @value={{this.selection}}
      @valueField={{this.valueField}}
      @valueRecords={{this.valueRecords}}
      @variant={{this.variant}}
    >
      <:option as |record config option|>
        {{#if (has-block "option")}}
          {{yield record config option to="option"}}
        {{else if (this.isShortcut record)}}
          <span class="d-tag-drop__shortcut">{{tagRecordName record}}</span>
        {{else}}
          <TagOption @config={{config}} @option={{option}} @record={{record}} />
        {{/if}}
      </:option>
      <:selection as |record config|>
        {{#if (has-block "selection")}}
          {{yield record config to="selection"}}
        {{else if @multiple}}
          <TagSelection @record={{record}} />
        {{else}}
          <span class="d-tag-drop__selection">
            {{~! no whitespace around the tag ~}}
            <TagSelection @record={{record}} />
          </span>
        {{/if}}
      </:selection>
      <:footer as |state config|>
        {{yield state config to="footer"}}
      </:footer>
    </DSelect>
  </template>
}
