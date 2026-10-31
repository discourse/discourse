import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import { modifier } from "ember-modifier";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { makeArray } from "discourse/lib/helpers";
import {
  cleanTagName,
  findTagsByNames,
  knownTagId,
  resolveTagNames,
  searchTags,
  storedName,
  type TagSearchContext,
  type TagSearchResult,
} from "discourse/lib/tag-source";
import type Site from "discourse/models/site";
import type User from "discourse/models/user";
import type SiteSettingsService from "discourse/services/site-settings";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import DSelect from "discourse/ui-kit/select/d-select";
import {
  TagOption,
  TagSelection,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-renderers";
import {
  type SelectTagTextKey,
  TAG_TEXTS,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-texts";
import {
  createTagItem,
  emitTags,
  tagItem,
  type TagKey,
  tagKey,
  type TagObject,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-values";
import type {
  SelectItem,
  SelectLoadOptions,
  SelectResolvedOptions,
  SelectTexts,
  SelectTextWrapper,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** The engine's public arguments and yielded blocks. */
type SelectSignature =
  DSelect extends Component<infer Signature> ? Signature : never;

/** The tag field's arguments; consumers keep their original held tag shapes. */
interface DSelectTagSignature {
  Args: {
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
    /** Additional persistent help element ids. */
    describedBy?: string;
  };
  Element: HTMLElement;
  Blocks: Pick<SelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/** Picks tags to store, as tag objects or, with `@emit="names"`, stored names. */
export default class DSelectTag extends Component<DSelectTagSignature> {
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

  /** The tag texts, named "Tag" while the field holds at most one, otherwise "Tags". */
  kindTexts: SelectTexts = {
    ...TAG_TEXTS,
    ariaLabel: (_values, context) =>
      context.multiple && this.maximum !== 1
        ? i18n("tagging.tags")
        : i18n("tagging.tag"),
  };

  /**
   * The requirement steps lead the placeholder: the required group, then the minimum, then the
   * prompt every layer set. A step whose text is empty hands over to the next.
   */
  kindTextWrappers: Readonly<Record<string, SelectTextWrapper>> = {
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
    // Signed out, held names are searched without their ids, as select-kit did.
    if (names.length && this.currentUser) {
      void waitForPromise(resolveTagNames(names)).catch(() => {
        // A later value change can retry; unresolved names never enter the context.
        if (this.#resolutionKey === key) {
          this.#resolutionKey = undefined;
        }
      });
    }
  });

  #resolutionKey: string | undefined;

  @tracked private _validation = new Map<string, TagSearchResult>();

  constructor(owner: Owner, args: DSelectTagSignature["Args"]) {
    super(owner, args);
    assertNoRemovedTextArgs("DSelectTag", args);
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
    const { ids, names } = this._selectionInputs;
    const resolved = names
      .map((name) => knownTagId(name))
      .filter((id) => id !== undefined);
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
      validation &&
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

  /**
   * Splits a pasted list on `|`. Held tags are passed through, so the engine reports them as
   * already held, and every other name is resolved in one lookup that applies the field's rules.
   * A name with no tag becomes a new one where creation is allowed.
   */
  @action
  parsePaste(text: string) {
    const names = text
      .split("|")
      .map((name) => name.trim())
      .filter(Boolean);
    if (names.length < 2) {
      return null;
    }
    const held = new Map(
      this.#tags.map((tag) => [
        storedName(typeof tag === "string" ? { name: tag } : tag).toLowerCase(),
        this.#itemForTag(tag),
      ])
    );
    const pasted = new Map<string, string>();
    for (const name of names) {
      const cleaned = cleanTagName(name, this.siteSettings);
      const lower = cleaned.toLowerCase();
      if (cleaned && !this.#excludedNames.has(lower) && !pasted.has(lower)) {
        pasted.set(lower, cleaned);
      }
    }
    const toItems = (
      rows: SelectItem[],
      forbiddenNames: readonly string[] = []
    ) => {
      const found = new Map(
        this.#prepareItems(rows).map((row) => [
          this.#storedItemName(row).toLowerCase(),
          row,
        ])
      );
      const forbidden = new Set(
        forbiddenNames.map((name) => name.toLowerCase())
      );
      return [...pasted].flatMap(([lower, name]): SelectItem[] => {
        const row = held.get(lower) ?? found.get(lower);
        if (row) {
          return row.disabled ? [] : [row];
        }
        return this.#creationAllowed && !forbidden.has(lower)
          ? [this.createItem(name)]
          : [];
      });
    };
    const lookup = [...pasted]
      .filter(([lower]) => !held.has(lower))
      .map(([, name]) => name);
    if (!lookup.length) {
      return toItems([]);
    }
    return findTagsByNames(lookup, { context: this.loadContext }).then(
      ({ items, forbiddenNames }) =>
        toItems(
          items.map((item) => ({ ...item })),
          forbiddenNames
        ),
      (error: unknown) => {
        popupAjaxError(error);
        return null;
      }
    );
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
      if (typeof tag === "string") {
        return { ...item, name: tag };
      }
      // A held object keeps its identity unless its id came from a lookup.
      return tagKey(tag) === item.id ? tag : { ...tag, id: item.id };
    });
    const tags = emitTags(keys, {
      held,
      items: rows as unknown as TagObject[],
    });
    const result = this.args.emit === "names" ? tags.map(storedName) : tags;
    this.args.onChange?.(this.args.multiple ? result : (result[0] ?? null));
  }

  /** Keys a held tag by its id, taking a held name's id from the session's lookups. */
  @action
  async load(filter: string, opts: SelectLoadOptions) {
    const context: TagSearchContext = opts.context ?? {};
    const result = await searchTags(filter, {
      context: {
        ...context,
        prioritizeRecentTags: filter ? undefined : context.prioritizeRecentTags,
      },
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
    return this.#prepareItems(result.items.map((item) => ({ ...item })));
  }

  #itemForTag(
    tag: TagObject | string
  ): SelectItem & { id: TagKey; name: string } {
    const item = { ...(typeof tag === "object" ? tag : {}), ...tagItem(tag) };
    if (typeof item.id === "number" || item.isNew) {
      return item;
    }
    const id = knownTagId(
      storedName(typeof tag === "string" ? { name: tag } : tag)
    );
    return id === undefined ? item : { ...item, id };
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
    const name = this.#storedItemName(item).toLowerCase();
    return this.#tags.some(
      (tag) =>
        this.#itemForTag(tag).id === item.id ||
        storedName(
          typeof tag === "string" ? { name: tag } : tag
        ).toLowerCase() === name
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

  <template>
    {{! TODO (select-kit-replacement-cleanup): Retain the legacy family class during rollout. }}
    <DSelect
      class="select-tag"
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
      @kind="select-tag"
      @kindContext={{hash value=@value categoryId=@categoryId exclude=@exclude}}
      @kindTexts={{this.kindTexts}}
      @kindTextWrappers={{this.kindTextWrappers}}
      @labelField="name"
      @legacyKind={{if @legacyKind @legacyKind "tag-chooser"}}
      @load={{this.load}}
      @loadContext={{this.loadContext}}
      @maximum={{this.maximum}}
      @maxVisibleChips={{@maxVisibleChips}}
      @minimum={{@minimum}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @parsePaste={{this.parsePaste}}
      @suppressFooter={{not (has-block "footer")}}
      @texts={{@texts}}
      @value={{this.selectedIds}}
      @valueItems={{this.valueItems}}
      @variant={{@variant}}
      {{this.resolveHeldNames}}
    >
      <:item as |item options row|>
        {{#if (has-block "item")}}
          {{yield item options row to="item"}}
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
