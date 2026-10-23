import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import { modifier } from "ember-modifier";
import {
  cleanTagName,
  findTagIdsByNames,
  searchTags,
  type TagSearchContext,
  type TagSearchResult,
} from "discourse/lib/tag-source";
import type Site from "discourse/models/site";
import type SiteSettingsService from "discourse/services/site-settings";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import type { SelectResolvedOptions } from "discourse/ui-kit/select/-internals/engine/customizations";
import DSelect, {
  type SelectPasteContext,
} from "discourse/ui-kit/select/d-select";
import {
  createTagItem,
  emitTags,
  type HeldTag,
  tagItem,
  type TagKey,
  tagKey,
  type TagObject,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-values";
import type {
  SelectItem,
  SelectLoadOptions,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** The engine's public arguments and yielded blocks, shared by tag recipes. */
type SelectSignature =
  DSelect extends Component<infer Signature> ? Signature : never;

/** Shared tag recipe arguments; consumers keep their original held tag shapes. */
export interface TagSelectSignature {
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
    tags?: readonly HeldTag[];
    /** Tags excluded from search and included in server selection rules. */
    blockedTags?: readonly HeldTag[];
    /** Category whose tag restrictions apply. */
    categoryId?: number;
    /** Bypass input restrictions when listing tags. */
    everyTag?: boolean;
    /** Exclude synonym rows. */
    excludeSynonyms?: boolean;
    /** Exclude tags that have synonyms. */
    excludeHasSynonyms?: boolean;
    /** Opt in to creation, also requiring the site's permission. Defaults to false. */
    allowCreate?: boolean;
    /** Whether creation needs an explicit opt-in or follows the site's permission. */
    creationPolicy?: "explicit" | "permitted";
    /** Suppress creation in fields that only accept existing tags. */
    preventCreate?: boolean;
    /** Held tags omitted from the visible selection. */
    hiddenValues?: readonly HeldTag[];
    /** Prefer recently used tags for an empty search when enabled by the site. */
    prioritizeRecentTags?: boolean;
    /** Selection cap; zero prevents additions. Overrides the site default. */
    maximum?: number;
    /** Ignore the site default cap. An explicit maximum still applies. */
    unlimitedTagCount?: boolean;
    /** Advisory minimum, also shown as persistent guidance. */
    minimum?: number;
    /** Receives selected tags in the consumer's shape. */
    onChange: (tags: TagObject[]) => void;
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
    /** Translated text displayed when no tags are selected. */
    placeholder?: string;
    /** Accessible control label. */
    label?: string;
    /** Additional persistent help element ids. */
    describedBy?: string;
  };
  Element: HTMLElement;
  Blocks: Pick<SelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/** Narrows optional source counts at the rendering boundary. */
function tagCount(item: SelectItem): number {
  return typeof item.count === "number" ? item.count : 0;
}

/** Narrows the optional synonym target supplied by tag search. */
function synonymName(item: SelectItem): string | undefined {
  const target = item.target_tag;
  return typeof target === "object" &&
    target !== null &&
    "name" in target &&
    typeof target.name === "string"
    ? target.name
    : undefined;
}

/** An item's display name, narrowed for templates. */
export function tagItemName(item: SelectItem): string {
  return typeof item.name === "string" ? item.name : String(item.name ?? "");
}

/** Narrows optional action icons at the rendering boundary. */
function actionIcon(item: SelectItem): string | undefined {
  return typeof item.icon === "string" ? item.icon : undefined;
}

/** Default option content shared with forwarding recipes. */
export const TagOption: TemplateOnlyComponent<{
  Args: {
    /** The tag row, including its optional count and synonym target. */
    item: SelectItem;
  };
}> = <template>
  {{#if @item.onSelect}}
    {{#if (actionIcon @item)}}{{dIcon (actionIcon @item)}}{{/if}}
    {{tagItemName @item}}
  {{else if @item.isNew}}
    {{i18n "d_select.create_item" label=@item.name}}
  {{else}}
    {{dDiscourseTag @item.name noHref=true tagName="span"}}
    {{#if @item.count}}
      <span aria-hidden="true" class="discourse-tag-count">x
        {{tagCount @item}}</span>
      <span class="sr-only">{{i18n
          "tagging.tag_count_hidden"
          count=(tagCount @item)
        }}</span>
    {{/if}}
    {{#if @item.target_tag}}
      <span class="synonym-hint"><span aria-hidden="true">→</span>
        {{synonymName @item}}</span>
    {{/if}}
  {{/if}}
</template>;

/** Default held-tag content shared with forwarding recipes. */
export const TagSelection: TemplateOnlyComponent<{
  Args: {
    /** The held tag supplied by the engine. */
    item: SelectItem;
  };
}> = <template>
  {{dDiscourseTag @item.name noHref=true tagName="span"}}
</template>;

/** Domain behavior shared by multi-tag selects. */
export default class TagSelectBase extends Component<TagSelectSignature> {
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

  helpId = `${guidFor(this)}-tag-guidance`;
  resolveHeldNames = modifier(() => {
    const { names, key } = this._selectionInputs;
    if (this.#resolutionKey === key) {
      return;
    }
    this.#resolutionKey = key;
    if (names.length) {
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

  #loadedItems: SelectItem[] = [];
  #resolutionKey: string | undefined;

  @tracked private _resolvedNames: { key: string; ids: number[] } | undefined;

  @tracked private _validation = new Map<string, TagSearchResult>();

  get #creationAllowed() {
    return (
      !this.args.preventCreate &&
      (this.args.creationPolicy === "permitted"
        ? this.args.allowCreate || this.site.can_create_tag
        : this.args.allowCreate && this.site.can_create_tag)
    );
  }

  get #tags() {
    const hidden = new Set((this.args.hiddenValues ?? []).map(tagKey));
    return (this.args.tags ?? []).filter((tag) => !hidden.has(tagKey(tag)));
  }

  @cached
  private get _selectionInputs() {
    const ids = new Set<number>();
    const names = new Set<string>();
    for (const tag of [
      ...(this.args.tags ?? []),
      ...(this.args.blockedTags ?? []),
    ]) {
      const key = tagKey(tag);
      if (typeof key === "number") {
        ids.add(key);
      } else if (typeof tag !== "object" || !tag.isNew) {
        names.add(tagItem(tag).name.toLowerCase());
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
      everyTag: this.args.everyTag,
      excludeSynonyms: this.args.excludeSynonyms,
      excludeHasSynonyms: this.args.excludeHasSynonyms,
      prioritizeRecentTags:
        this.args.prioritizeRecentTags &&
        this.siteSettings.prioritize_recently_used_tags
          ? true
          : undefined,
      selectedTagIds: [...new Set([...ids, ...resolved])],
    };
  }

  get maximum() {
    return (
      this.args.maximum ??
      (this.args.unlimitedTagCount
        ? undefined
        : this.siteSettings.max_tags_per_topic)
    );
  }

  get value() {
    return this.#tags.map(tagKey);
  }

  get valueItems() {
    return this.#tags.map((tag) => ({ ...tagItem(tag) }));
  }

  get guidance() {
    const required = this._validation.get(
      this.#validationKey(this.loadContext, "")
    )?.requiredTagGroup;
    return required
      ? i18n("tagging.choose_for_topic_required_group", {
          count: required.min_count,
          name: required.name,
        })
      : this.args.minimum
        ? i18n("tagging.choose_for_topic_required", {
            count: this.args.minimum,
          })
        : undefined;
  }

  get describedBy() {
    return (
      [this.args.describedBy, this.guidance ? this.helpId : undefined]
        .filter(Boolean)
        .join(" ") || undefined
    );
  }

  @action
  async load(filter: string, opts: SelectLoadOptions) {
    if (this.args.load) {
      const result = await this.args.load(filter, opts);
      if (!opts.signal?.aborted && !this.isDestroying) {
        const items = Array.isArray(result) ? result : result.items;
        this.#loadedItems = opts.offset
          ? [...this.#loadedItems, ...items]
          : items;
      }
      return result;
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
      validation.set(this.#validationKey(context, ""), result);
      this._validation = validation;
    }
    const blocked = new Set(
      (this.args.blockedTags ?? []).map((tag) =>
        tagItem(tag).name.toLowerCase()
      )
    );
    const items = result.items
      .filter((item) => !blocked.has(item.name.toLowerCase()))
      .map((item) =>
        this.maximum === 0 ? { ...item, disabled: true } : { ...item }
      );
    if (!opts.signal?.aborted && !this.isDestroying) {
      this.#loadedItems = opts.offset
        ? [...this.#loadedItems, ...items]
        : items;
    }
    return items;
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
    const maximum = this.maximum === 0 ? 0 : options.maximum;
    return !!(
      this.#creationAllowed &&
      name &&
      validation &&
      !validation.forbidden &&
      (typeof maximum !== "number" || this.#tags.length < maximum) &&
      !items.some((item) =>
        [item.name, item.text].some(
          (label) =>
            typeof label === "string" &&
            label.toLowerCase() === name.toLowerCase()
        )
      ) &&
      !this.#tags.some(
        (tag) => tagItem(tag).name.toLowerCase() === name.toLowerCase()
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
        : this.args.items) ?? this.#loadedItems;
    const blocked = new Set(
      (this.args.blockedTags ?? []).map((tag) =>
        tagItem(tag).name.toLowerCase()
      )
    );
    return names.flatMap((name) => {
      if (blocked.has(name.toLowerCase())) {
        return [];
      }
      const existing = items.find(
        (item) => tagItemName(item).toLowerCase() === name.toLowerCase()
      );
      if (existing) {
        return [existing];
      }
      const cleaned = cleanTagName(name, this.siteSettings);
      return this.#creationAllowed && cleaned && this.maximum !== 0
        ? [this.createItem(cleaned)]
        : [];
    });
  }

  @action
  onChange(ids: SelectValue, items: SelectItem | SelectItem[] | null) {
    if (!Array.isArray(ids) || !Array.isArray(items)) {
      return;
    }
    const heldKeys = new Set(this.value);
    if (this.maximum === 0 && ids.some((id) => !heldKeys.has(id as TagKey))) {
      return;
    }
    this.args.onChange(
      emitTags(ids as TagKey[], {
        held: this.#tags,
        items: items as unknown as TagObject[],
      })
    );
  }

  #validationKey(context: TagSearchContext, term: string) {
    return JSON.stringify([context, term]);
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Retain the legacy family class during rollout. }}
    <DSelect
      class={{@kind}}
      ...attributes
      @allowCreate={{this.allowCreate}}
      @createItem={{this.createItem}}
      @describedBy={{this.describedBy}}
      @disabled={{@disabled}}
      @icon={{@icon}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @items={{@items}}
      @kind={{@kind}}
      @kindContext={{@kindContext}}
      @kindOptions={{@kindOptions}}
      @label={{@label}}
      @labelField="name"
      @load={{this.load}}
      @loadContext={{this.loadContext}}
      @maximum={{this.maximum}}
      @maxVisibleChips={{@maxVisibleChips}}
      @minimum={{@minimum}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @parsePaste={{this.parsePaste}}
      @placeholder={{if
        @placeholder
        @placeholder
        (i18n "tagging.choose_for_topic")
      }}
      @value={{this.value}}
      @valueItems={{this.valueItems}}
      {{this.resolveHeldNames}}
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
    </DSelect>
    {{#if this.guidance}}
      <p id={{this.helpId}}>{{this.guidance}}</p>
    {{/if}}
  </template>
}
