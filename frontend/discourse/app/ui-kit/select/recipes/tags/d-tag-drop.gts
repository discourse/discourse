import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { searchTags, sortTagRows, topTags } from "discourse/lib/tag-source";
import DiscourseURL, { getCategoryAndTagUrl } from "discourse/lib/url";
import type Category from "discourse/models/category";
import type Site from "discourse/models/site";
import type SiteSettingsService from "discourse/services/site-settings";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import type { SelectResolvedOptions } from "discourse/ui-kit/select/-internals/engine/customizations";
import DSelect from "discourse/ui-kit/select/d-select";
import {
  tagItemName,
  TagOption,
  TagSelection,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-select-base";
import {
  ALL_TAGS_ID,
  NO_TAG_ID,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-values";
import type {
  SelectItem,
  SelectLoadOptions,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

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

/** Single tag filter with optional local data and routing overrides. */
interface DTagDropSignature {
  Args: {
    /** Current tag filter, including the special untagged filter. */
    tag?: FilterTag | null;
    /** Category whose tag filter should be changed. */
    currentCategory?: Category;
    /** Exclude subcategories from the resulting route. */
    noSubcategories?: boolean;
    /** Local tags replacing the site's top tags and server search. */
    items?: readonly FilterTag[];
    /** Optional asynchronous source override. */
    load?: SelectSignature["Args"]["load"];
    /** Replaces navigation with a call-site selection handler. */
    onChange?: (id: number | string, tag: FilterTag) => void;
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

/** Navigates between tag filters while retaining the legacy shortcut keys. */
export default class DTagDrop extends Component<DTagDropSignature> {
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
  };

  @tracked expanded = false;
  @tracked moreTags = false;

  get tagClass() {
    return this.args.tag?.slug ? `tag-${this.args.tag.slug}` : "tag_all";
  }

  get selection() {
    const tag = this.args.tag;
    if (tag?.name === "none" || tag?.name === NO_TAG_ID) {
      return { id: NO_TAG_ID, name: i18n("tagging.selector_no_tags") };
    }
    return tag?.id
      ? tag
      : { id: ALL_TAGS_ID, name: i18n("tagging.selector_tags") };
  }

  get loadContext() {
    return {
      categoryId: (this.args.currentCategory as { id?: number } | undefined)
        ?.id,
      items: this.args.items,
      tagId: this.args.tag?.id,
      tagName: this.args.tag?.name,
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
        context: { everyTag: true },
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
          categoryId: (this.args.currentCategory as { id?: number } | undefined)
            ?.id,
        })),
    ];
    this.moreTags =
      !filter && tags.length > this.siteSettings.max_tags_in_filter_list;
    const shortcuts: FilterTag[] = [];
    if (this.args.tag?.name) {
      shortcuts.push({
        id: ALL_TAGS_ID,
        name: i18n("tagging.selector_remove_filter"),
      });
    }
    if (!["none", NO_TAG_ID].includes(this.args.tag?.name ?? "")) {
      shortcuts.push({ id: NO_TAG_ID, name: i18n("tagging.selector_no_tags") });
    }
    return [
      ...shortcuts,
      ...sortTagRows(tags.slice(0, this.siteSettings.max_tags_in_filter_list), {
        alphabetical: this.siteSettings.tags_sort_alphabetically,
      }),
    ].filter(
      (tag) => !filter || tag.name.toLowerCase().includes(filter.toLowerCase())
    );
  }

  @action
  onChange(id: SelectValue, item: SelectItem | SelectItem[] | null) {
    if (
      (typeof id !== "string" && typeof id !== "number") ||
      !item ||
      Array.isArray(item) ||
      typeof item.name !== "string"
    ) {
      return;
    }
    const tag: FilterTag = { ...item, id, name: item.name };
    if (this.args.onChange) {
      this.args.onChange(id, tag);
      return;
    }
    const tagArg =
      id === NO_TAG_ID
        ? "none"
        : id === ALL_TAGS_ID
          ? null
          : (tag.target_tag ?? tag);
    DiscourseURL.routeToUrl(
      getCategoryAndTagUrl(
        this.args.currentCategory,
        !this.args.noSubcategories,
        tagArg
      )
    );
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
    {{! TODO (select-kit-replacement-cleanup): Retain the legacy family and filter classes during rollout. }}
    <DSelect
      class={{dConcatClass "tag-drop" this.tagClass}}
      ...attributes
      @disabled={{@disabled}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @kind="tag-drop"
      @kindContext={{hash
        tag=@tag
        currentCategory=@currentCategory
        noSubcategories=@noSubcategories
      }}
      @kindOptions={{hash caretDownIcon="angle-right" caretUpIcon="angle-down"}}
      @label={{if @label @label (i18n "tagging.selector_tags")}}
      @labelField="name"
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
        {{#if (has-block "item")}}{{yield item options to="item"}}{{else if
          (this.isShortcut item)
        }}<span class="d-tag-drop__shortcut">{{tagItemName
              item
            }}</span>{{else}}<TagOption @item={{item}} />{{/if}}
      </:item>
      <:selection as |item options|>
        {{#if (has-block "selection")}}
          {{yield item options to="selection"}}
        {{else}}
          <span class="d-tag-drop__selection"><TagSelection
              @item={{item}}
            />{{dIcon (this.caret options)}}</span>
        {{/if}}
      </:selection>
      <:footer as |state options|>
        {{#if (has-block "footer")}}{{yield state options to="footer"}}{{else if
          this.moreTags
        }}
          <span class="d-tag-drop__filter-for-more">{{i18n
              "select_kit.components.filter_for_more"
            }}</span>
        {{/if}}
      </:footer>
    </DSelect>
  </template>
}
