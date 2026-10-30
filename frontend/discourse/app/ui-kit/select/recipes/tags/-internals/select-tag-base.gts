import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import { modifier } from "ember-modifier";
import { makeArray } from "discourse/lib/helpers";
import {
  cleanTagName,
  findTagIdsByNames,
  searchTags,
  storedName,
  type TagSearchContext,
  type TagSearchResult,
} from "discourse/lib/tag-source";
import type Site from "discourse/models/site";
import type User from "discourse/models/user";
import type SiteSettingsService from "discourse/services/site-settings";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import DSelect, {
  type SelectPasteContext,
} from "discourse/ui-kit/select/d-select";
import {
  TagOption,
  TagSelection,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-renderers";
import {
  createTagItem,
  emitTags,
  tagItem,
  type TagKey,
  tagKey,
  type TagObject,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-values";
import type {
  SelectCoreTextKey,
  SelectItem,
  SelectKindTexts,
  SelectLoadOptions,
  SelectResolvedOptions,
  SelectTexts,
  SelectTextWrapper,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** The texts a tag picker accepts: the engine's and the tag recipe's. */
export type SelectTagTextKey =
  | SelectCoreTextKey
  | "addMoreTags"
  | "requiredTagGroup"
  | "requiredTagGroupRemaining"
  | "minimumPlaceholder"
  | "minimumRemaining"
  | "tagCountBadge"
  | "tagCount";

/**
 * The tag texts. The placeholder is the prompt the requirement steps fall back to, and the panel's
 * minimum line counts progress so it never repeats the field's "Select at least…".
 */
export const TAG_TEXTS: SelectTexts = Object.freeze({
  placeholder: { key: "tagging.choose_for_topic" },
  addMorePlaceholder: (_values, context) => context.text("addMoreTags"),
  minimum: { key: "tagging.required_tags_progress" },
  maximum: { key: "tagging.max_tags_reached" },
  requiredTagGroup: { key: "tagging.choose_for_topic_required_group" },
  requiredTagGroupRemaining: { key: "tagging.choose_more_required_group" },
  minimumPlaceholder: { key: "tagging.choose_for_topic_required" },
  minimumRemaining: { key: "tagging.choose_more_required" },
  addMoreTags: { key: "tagging.add_more_tags" },
  tagCountBadge: { key: "tagging.tag_count_badge" },
  tagCount: { key: "tagging.tag_count_hidden" },
});

/** The engine's public arguments and yielded blocks, shared by tag recipes. */
type SelectSignature =
  DSelect extends Component<infer Signature> ? Signature : never;

/** Shared tag recipe arguments; consumers keep their original held tag shapes. */
export interface SelectTagBaseSignature {
  Args: {
    /** Recipe family used by select customizations and rollout styles. */
    kind: string;
    /** Raw recipe state exposed to customizations. */
    kindContext?: object;
    /** Additional recipe options exposed to customizations. */
    kindOptions?: Record<string, unknown>;
    /** Call-site customization identity, never assigned by the recipe. */
    identifier?: string;
    /** Call-site state exposed to customizations. */
    instanceContext?: object;
    /** Controlled held tags, rendered without a resolver. */
    value?: readonly (TagObject | string)[] | TagObject | string | null;
    /** Tags excluded from search and included in server selection rules. */
    exclude?: readonly (TagObject | string)[];
    /** Category whose tag restrictions apply. */
    categoryId?: number;
    /** Bypass input restrictions when listing tags. */
    ignoreRestrictions?: boolean;
    /** Exclude synonym rows. */
    excludeSynonyms?: boolean;
    /** Exclude tags that have synonyms. */
    excludeTagsWithSynonyms?: boolean;
    /** Opt in to creation, also requiring the site's permission. Defaults to false. */
    allowCreate?: boolean;
    /** Emit stored names instead of tag objects. */
    emit?: "names";
    /** Holds several tags; defaults to one, as DSelect does. */
    multiple?: boolean;
    /** Prefer recently used tags when the site enables suggestions. */
    suggestRecent?: boolean;
    /** Omitted uses the site limit; false removes the cap. */
    maximum?: number | false;
    /** Temporary compatibility aliases for legacy customizations and CSS. */
    legacyKind?: SelectSignature["Args"]["legacyKind"];
    /** Trigger presentation. */
    variant?: SelectSignature["Args"]["variant"];
    /** Advisory minimum, shown in the field's placeholder until it's met. */
    minimum?: number;
    /** Receives selected tags in the consumer's shape. */
    onChange?: (
      tags: TagObject[] | TagObject | string[] | string | null
    ) => void;
    /** Optional local source forwarded to the engine. */
    items?: SelectSignature["Args"]["items"];
    /** Optional source override forwarded to the engine. */
    load?: SelectSignature["Args"]["load"];
    /** Prevents opening the control or changing its selection. */
    disabled?: boolean;
    /** Icon displayed at the start of the trigger. */
    icon?: string;
    /** Visible chip limit; zero shows only the selection count. */
    maxVisibleChips?: number;
    /** Marks a selection invalid when validation belongs to the surrounding form. */
    invalid?: boolean;
    /** Id of the combobox element, for an external label. */
    id?: string;
    /** Ids of visible captions that name the control, replacing the default name. */
    ariaLabelledBy?: string;
    /**
     * The field's texts, over the tag defaults. A `placeholder` replaces only the prompt: a
     * required group or a minimum still leads it, each worded through its own key.
     */
    texts?: SelectTexts<SelectTagTextKey>;
    /** A recipe built on this one: its texts, above the tag defaults. */
    kindTexts?: SelectTexts;
    /** Whether the placeholder carries the required group and the minimum. Defaults to true. */
    requirementPlaceholders?: boolean;
    /** Additional persistent help element ids. */
    describedBy?: string;
    /** Skips the forwarded `:footer` block; see `DSelect`'s `@suppressFooter`. */
    suppressFooter?: boolean;
  };
  Element: HTMLElement;
  Blocks: Pick<SelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/** Stored-name selection and explicit creation shared by the new tag recipes. */
export default class SelectTagBase extends Component<SelectTagBaseSignature> {
  @service declare currentUser: User | null;

  /** TODO(typescript-pending): Remove the extension when Site types serialized permissions. */
  @service declare site: Site & { can_create_tag: boolean };

  /** TODO(typescript-pending): Remove the extension when the settings factory exposes its runtime keys. */
  @service
  declare siteSettings: SiteSettingsService & {
    max_tags_per_topic: number;
    max_tag_search_results: number;
    tags_sort_alphabetically: boolean;
    max_tag_length: number;
    force_lowercase_tags: boolean;
    prioritize_recently_used_tags: boolean;
  };

  /**
   * The requirement steps lead the placeholder: the required group, then the minimum, then the
   * prompt every layer set. A step whose text is empty hands over to the next.
   */
  kindTextWrappers?: Readonly<Record<string, SelectTextWrapper>> =
    this.args.requirementPlaceholders === false
      ? undefined
      : {
          placeholder: (final, _values, context) => {
            if (this.#zeroCap) {
              return final;
            }
            const group = this.#requiredGroup;
            const minimum = this.args.minimum ?? 0;
            return (
              (group &&
                context.text("requiredTagGroup", {
                  count: group.min_count,
                  name: group.name,
                })) ||
              (minimum > 0 &&
                context.text("minimumPlaceholder", { count: minimum })) ||
              final
            );
          },
          addMorePlaceholder: (final, values, context) => {
            if (this.#zeroCap) {
              return "";
            }
            const group = this.#requiredGroup;
            const remaining =
              Number(values.minimum ?? 0) - Number(values.selected ?? 0);
            return (
              (group &&
                context.text("requiredTagGroupRemaining", {
                  count: group.remaining_count,
                  name: group.name,
                })) ||
              (remaining > 0 &&
                context.text("minimumRemaining", { count: remaining })) ||
              final
            );
          },
        };

  resolveHeldNames = modifier(() => {
    const { names, key } = this._selectionInputs;
    if (this.#resolutionKey === key) {
      return;
    }
    this.#resolutionKey = key;
    // The list endpoint needs a login; signed out, held names are searched without their ids.
    if (names.length && this.currentUser) {
      void waitForPromise(findTagIdsByNames(names)).then(
        (ids) => {
          if (!this.isDestroying && this.#resolutionKey === key) {
            this._resolvedNames = { key, ids: [...ids] };
          }
        },
        () => {
          // A later value change can retry; unresolved names never enter the context.
          if (this.#resolutionKey === key) {
            this.#resolutionKey = undefined;
          }
        }
      );
    }
  });

  /** The control's name: "Tag" while it holds at most one, otherwise "Tags". */
  #nameTexts: SelectTexts = {
    ariaLabel: (_values, context) =>
      context.multiple && this.maximum !== 1
        ? i18n("tagging.tags")
        : i18n("tagging.tag"),
  };

  #resolutionKey: string | undefined;
  @tracked private _loadedItems: SelectItem[] = [];

  @tracked private _resolvedNames: { key: string; ids: number[] } | undefined;

  @tracked private _validation = new Map<string, TagSearchResult>();

  constructor(owner: Owner, args: SelectTagBaseSignature["Args"]) {
    super(owner, args);
    assertNoRemovedTextArgs("SelectTagBase", args);
  }

  get #creationAllowed() {
    return this.args.allowCreate && this.site.can_create_tag && !this.#zeroCap;
  }

  get #excludedNames() {
    return new Set(
      (this.args.exclude ?? []).map((tag) =>
        storedName(typeof tag === "string" ? { name: tag } : tag).toLowerCase()
      )
    );
  }

  get #tags(): readonly (TagObject | string)[] {
    const value = this.args.value;
    if (!value) {
      return [];
    }
    return makeArray(value as TagObject | string | (TagObject | string)[]);
  }

  get #zeroCap() {
    return (
      this.args.maximum === undefined &&
      this.siteSettings.max_tags_per_topic === 0
    );
  }

  @cached
  private get _selectionInputs() {
    const ids = new Set<number>();
    const names = new Set<string>();
    for (const tag of [
      ...(this.args.multiple ? this.#tags : []),
      ...(this.args.exclude ?? []),
    ]) {
      const key = tagKey(tag);
      if (typeof key === "number") {
        ids.add(key);
      } else if (typeof tag !== "object" || !tag.isNew) {
        names.add(
          storedName(
            typeof tag === "string" ? { name: tag } : tag
          ).toLowerCase()
        );
      }
    }
    const sortedNames = [...names].sort();
    return {
      ids: [...ids],
      names: sortedNames,
      key: JSON.stringify(sortedNames),
    };
  }

  @cached
  get loadContext() {
    const { ids, key } = this._selectionInputs;
    const resolved =
      this._resolvedNames?.key === key ? this._resolvedNames.ids : [];
    return {
      categoryId: this.args.categoryId,
      everyTag: this.args.ignoreRestrictions,
      excludeSynonyms: this.args.excludeSynonyms,
      excludeHasSynonyms: this.args.excludeTagsWithSynonyms,
      prioritizeRecentTags:
        this.args.suggestRecent &&
        this.siteSettings.prioritize_recently_used_tags
          ? true
          : undefined,
      selectedTagIds: [...new Set([...ids, ...resolved])],
    };
  }

  get maximum() {
    return this.#zeroCap
      ? false
      : (this.args.maximum ?? this.siteSettings.max_tags_per_topic);
  }

  get selectedIds() {
    assert(
      'DSelectTag: @emit must be "names" or undefined',
      this.args.emit === undefined || this.args.emit === "names"
    );
    const keys = this.#tags.map((tag) => this.#itemForTag(tag).id);
    return this.args.multiple ? keys : (keys[0] ?? null);
  }

  get valueItems() {
    return this.#tags.map((tag) => this.#itemForTag(tag));
  }

  get sourceLoad() {
    return this.args.load ||
      !this.args.items ||
      typeof this.args.items === "function"
      ? this._load
      : undefined;
  }

  get localItems(): SelectSignature["Args"]["items"] {
    if (this.sourceLoad || !this.args.items) {
      return undefined;
    }
    return (options) => {
      const items =
        typeof this.args.items === "function"
          ? this.args.items(options)
          : (this.args.items ?? []);
      return this.#prepareItems(items ?? []);
    };
  }

  get kindTexts(): SelectKindTexts {
    return [TAG_TEXTS, this.#nameTexts, this.args.kindTexts ?? {}];
  }

  /** The first unmet required group, as the blank search for the current context reported it. */
  get #requiredGroup() {
    return this._validation.get(this.#validationKey(this.loadContext, ""))
      ?.requiredTagGroup;
  }

  @action
  allowCreate(
    filter: string,
    items: SelectItem[],
    options: SelectResolvedOptions
  ) {
    const name = cleanTagName(filter, this.siteSettings);
    const validation = this._validation.get(
      this.#validationKey(this.loadContext, name)
    );
    const maximum = this.#zeroCap ? 0 : options.maximum;
    return !!(
      this.#creationAllowed &&
      name &&
      (validation || this.args.items || this.args.load) &&
      !validation?.forbidden &&
      !this.#excludedNames.has(name.toLowerCase()) &&
      (typeof maximum !== "number" || this.#tags.length < maximum) &&
      !items.some(
        (item) =>
          this.#storedItemName(item).toLowerCase() === name.toLowerCase()
      ) &&
      !this.#tags.some(
        (tag) =>
          storedName(
            typeof tag === "string" ? { name: tag } : tag
          ).toLowerCase() === name.toLowerCase()
      )
    );
  }

  @action
  createItem(filter: string) {
    return { ...createTagItem(cleanTagName(filter, this.siteSettings)) };
  }

  @action
  parsePaste(text: string, { options }: SelectPasteContext) {
    const names = text
      .split("|")
      .map((name) => name.trim())
      .filter(Boolean);
    if (names.length < 2) {
      return null;
    }
    const items =
      (typeof this.args.items === "function"
        ? this.args.items(options)
        : this.args.items) ?? this._loadedItems;
    return names.flatMap((name) => {
      if (this.#excludedNames.has(name.toLowerCase())) {
        return [];
      }
      const existing = items.find(
        (item) =>
          this.#storedItemName(item).toLowerCase() === name.toLowerCase()
      );
      if (existing) {
        return [existing];
      }
      const cleaned = cleanTagName(name, this.siteSettings);
      return this.#creationAllowed && cleaned && !this.#zeroCap
        ? [this.createItem(cleaned)]
        : [];
    });
  }

  @action
  onChange(ids: SelectValue, items: SelectItem | SelectItem[] | null) {
    const keys = makeArray(ids) as TagKey[];
    const rows = makeArray(items);
    const heldKeys = new Set(this.valueItems.map((item) => item.id));
    if (this.#zeroCap && keys.some((id) => !heldKeys.has(id))) {
      return;
    }
    const held = this.#tags.map((tag) => {
      const item = this.#itemForTag(tag);
      return typeof tag === "object" ? tag : { ...item, name: tag };
    });
    const tags = emitTags(keys, {
      held,
      items: rows as unknown as TagObject[],
    });
    const result = this.args.emit === "names" ? tags.map(storedName) : tags;
    this.args.onChange?.(this.args.multiple ? result : (result[0] ?? null));
  }

  #itemForTag(
    tag: TagObject | string
  ): SelectItem & { id: TagKey; name: string } {
    if (typeof tag === "string") {
      const items =
        Array.isArray(this.args.items) && !this.args.load
          ? this.args.items
          : this._loadedItems;
      const loaded = items.find(
        (row) => this.#storedItemName(row).toLowerCase() === tag.toLowerCase()
      );
      if (loaded) {
        return loaded as SelectItem & { id: TagKey; name: string };
      }
    }
    return { ...(typeof tag === "object" ? tag : {}), ...tagItem(tag) };
  }

  #prepareItems(items: SelectItem[]) {
    const excluded = this.#excludedNames;
    return items
      .filter((item) => !excluded.has(this.#storedItemName(item).toLowerCase()))
      .map((item) =>
        this.#zeroCap && !this.#isHeld(item)
          ? { ...item, disabled: true }
          : item
      );
  }

  #isHeld(item: SelectItem) {
    return this.#tags.some((tag) =>
      typeof tag === "string"
        ? tag.toLowerCase() === this.#storedItemName(item).toLowerCase()
        : tagKey(tag) === item.id
    );
  }

  #storedItemName(item: SelectItem) {
    return storedName({
      name: String(item.name ?? ""),
      original_name:
        typeof item.original_name === "string" ? item.original_name : undefined,
    });
  }

  #validationKey(context: TagSearchContext, term: string) {
    return JSON.stringify([context, term]);
  }

  @action
  private async _load(filter: string, opts: SelectLoadOptions) {
    if (this.args.load) {
      const result = await this.args.load(filter, opts);
      const items = this.#prepareItems(
        Array.isArray(result) ? result : result.items
      );
      if (!opts.signal?.aborted && !this.isDestroying) {
        this._loadedItems = opts.offset
          ? [...this._loadedItems, ...items]
          : items;
      }
      return Array.isArray(result) ? items : { ...result, items };
    }
    if (typeof this.args.items === "function" && opts.options) {
      const items = this.#prepareItems(this.args.items(opts.options) ?? []);
      this._loadedItems = items;
      return items.filter((item) =>
        String(item.name ?? "")
          .toLowerCase()
          .includes(filter.toLowerCase())
      );
    }
    const context: TagSearchContext = opts.context ?? {};
    const result = await searchTags(filter, {
      context: {
        ...context,
        prioritizeRecentTags: filter ? undefined : context.prioritizeRecentTags,
      },
      signal: opts.signal,
      siteSettings: this.siteSettings,
    });
    if (!opts.signal?.aborted && !this.isDestroying) {
      const validation = new Map(this._validation);
      validation.set(
        this.#validationKey(context, cleanTagName(filter, this.siteSettings)),
        result
      );
      this._validation = validation;
    }
    const items = this.#prepareItems(result.items.map((item) => ({ ...item })));
    if (!opts.signal?.aborted && !this.isDestroying) {
      this._loadedItems = opts.offset
        ? [...this._loadedItems, ...items]
        : items;
    }
    return items;
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Retain the legacy family class during rollout. }}
    <DSelect
      class={{@kind}}
      ...attributes
      @allowCreate={{this.allowCreate}}
      @ariaLabelledBy={{@ariaLabelledBy}}
      @createItem={{this.createItem}}
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @icon={{@icon}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @items={{this.localItems}}
      @kind={{@kind}}
      @kindContext={{@kindContext}}
      @kindOptions={{@kindOptions}}
      @kindTexts={{this.kindTexts}}
      @kindTextWrappers={{this.kindTextWrappers}}
      @labelField="name"
      @legacyKind={{@legacyKind}}
      @load={{this.sourceLoad}}
      @loadContext={{this.loadContext}}
      @maximum={{this.maximum}}
      @maxVisibleChips={{@maxVisibleChips}}
      @minimum={{@minimum}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @parsePaste={{this.parsePaste}}
      @suppressFooter={{@suppressFooter}}
      @texts={{@texts}}
      @value={{this.selectedIds}}
      @valueItems={{this.valueItems}}
      @variant={{@variant}}
      {{this.resolveHeldNames}}
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
    </DSelect>
  </template>
}
