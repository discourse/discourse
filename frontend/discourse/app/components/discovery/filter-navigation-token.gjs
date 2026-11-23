import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, next } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import moment from "moment";
import DMenu from "discourse/float-kit/components/d-menu";
import withEventValue from "discourse/helpers/with-event-value";
import discourseDebounce from "discourse/lib/debounce";
import { parseFilterToken } from "discourse/lib/filter-query-tokens";
import FilterSuggestions from "discourse/lib/filter-suggestions";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import DDatePicker from "discourse/ui-kit/d-date-picker";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const FILTER_ICONS = {
  category: "folder",
  categories: "folder",
  tag: "tag",
  tags: "tag",
  "tag-group": "tags",
  tag_group: "tags",
  "created-by": "user",
  users: "user",
  group: "users",
  groups: "users",
  status: "circle-half-stroke",
  order: "arrow-down-wide-short",
  in: "inbox",
  topic: "hashtag",
  locale: "globe",
};

/** Finds a category by slug, or by the `parent:child` path the server accepts. */
export function findCategory(slug) {
  return slug.includes(":")
    ? Category.findBySlugPath(slug.split(":"))
    : Category.findBySlug(slug);
}

const NUMBER_FILTER = /^(likes-op|likes|posts|posters|views)-(min|max)$/;
const DATE_FILTER =
  /^(created|activity|latest-post|bookmarked)-(before|after)$/;
const DATE_VALUE = /^\d{4}-\d{1,2}-\d{1,2}$/;

/**
 * Spells out number and date filters ("At least 5 likes", "Created in the
 * last 7 days"), since an icon and a bare value can't tell them apart.
 */
function literalLabel(filterName, value) {
  if (!/^\d+$/.test(value) && !DATE_VALUE.test(value)) {
    return null;
  }

  const numberMatch = filterName.match(NUMBER_FILTER);
  if (numberMatch && /^\d+$/.test(value)) {
    const [, name, bound] = numberMatch;
    return i18n(`filter.token_label.${underscore(name)}_${bound}`, {
      count: Number(value),
    });
  }

  const dateMatch = filterName.match(DATE_FILTER);
  if (!dateMatch) {
    return null;
  }

  const key = `filter.token_label.${underscore(dateMatch[1])}_${dateMatch[2]}`;

  if (DATE_VALUE.test(value)) {
    return i18n(`${key}_date`, {
      date: moment(value, "YYYY-MM-DD").format("ll"),
    });
  }

  // the server reads a bare number as "this many days ago, from midnight"
  const days = Number(value);
  return days === 0
    ? i18n(`${key}_today`)
    : i18n(`${key}_days`, { count: days });
}

function underscore(name) {
  return name.replace(/-/g, "_");
}

const FILTER_ICON_PREFIXES = [
  ["likes", "heart"],
  ["views", "eye"],
  ["posters", "users"],
  ["posts", "comment"],
];

function iconForFilter(filterName, tip) {
  if (FILTER_ICONS[filterName]) {
    return FILTER_ICONS[filterName];
  }

  const match = FILTER_ICON_PREFIXES.find(([prefix]) =>
    filterName.startsWith(prefix)
  );
  if (match) {
    return match[1];
  }

  return tip?.type === "date" ? "calendar-days" : "filter";
}

/**
 * Categories another include filter already covers along with their
 * subcategories; offering them again would only repeat that filter.
 * An "only" filter covers nothing, so its subcategories can still be added.
 */
function coveredCategoryIds({ prefix, tips, tokens, index }) {
  const ids = new Set();

  if (prefix.includes("-")) {
    return ids;
  }

  (tokens || []).forEach((raw, i) => {
    if (i === index) {
      return;
    }

    const other = parseFilterToken(raw);
    const tip = FilterSuggestions.findTipForFilter(other.filterName, tips);

    if (tip?.type !== "category" || !other.value || /[-=]/.test(other.prefix)) {
      return;
    }

    other.value
      .split(",")
      .map(findCategory)
      .filter(Boolean)
      .forEach((category) =>
        category.descendants.forEach((c) => ids.add(c.id))
      );
  });

  return ids;
}

/**
 * What a value picker needs to edit `{prefix}{filterName}:{value}`.
 *
 * @param {object} options
 * @param {string} options.filterName
 * @param {string} [options.prefix]
 * @param {string} [options.value]
 * @param {object[]} [options.tips]
 * @param {string[]} [options.tokens] - every token in the query
 * @param {number} [options.index] - this token's place in `tokens`, if any
 * @param {(value: string, prefix: string) => void} options.onCommit
 * @param {() => void} [options.onBack] - shows a back button in the heading
 */
export function filterEditorData({
  filterName,
  prefix = "",
  value = "",
  tips = [],
  tokens,
  index,
  onCommit,
  onBack,
}) {
  const tip = FilterSuggestions.findTipForFilter(filterName, tips);
  const isCategory = tip?.type === "category";

  return {
    prefix,
    filterName,
    value,
    delimiters: tip?.delimiters,
    isCategory,
    isDate: tip?.type === "date",
    coveredCategoryIds: isCategory
      ? coveredCategoryIds({ prefix, tips, tokens, index })
      : new Set(),
    tips,
    onCommit,
    onBack,
  };
}

const EditorHeading = <template>
  <div class="filter-navigation-token__editor-heading">
    {{#if @data.onBack}}
      <DButton
        class="filter-navigation-token__editor-back btn-transparent"
        @action={{@data.onBack}}
        @icon="chevron-left"
        @title="filter.back_to_filters"
      />
    {{/if}}
    <span class="filter-navigation-token__editor-title">
      {{@data.prefix}}{{@data.filterName}}
    </span>
  </div>
</template>;

class FilterTokenDateEditor extends Component {
  @service site;

  @tracked calendarReady = false;
  @tracked
  days = /^\d+$/.test(this.args.data.value || "") ? this.args.data.value : "";

  calendarId = `filter-token-calendar-${guidFor(this)}`;
  maxDate = new Date();

  get daysHint() {
    return /^\d+$/.test(this.days)
      ? literalLabel(this.args.data.filterName, this.days)
      : null;
  }

  get selectedDate() {
    return DATE_VALUE.test(this.args.data.value || "")
      ? this.args.data.value
      : null;
  }

  @action
  commit(value) {
    this.args.data.onCommit(String(value));
    this.args.close();
  }

  @action
  calendarContainerInserted() {
    next(() => (this.calendarReady = true));
  }

  @action
  focusDays(element) {
    element.focus();
    element.select();
  }

  @action
  updateDays(value) {
    this.days = value;
  }

  @action
  commitCustomDays(event) {
    if (event.key !== "Enter") {
      return;
    }
    event.preventDefault();
    event.stopPropagation();

    const days = parseInt(event.target.value, 10);
    if (Number.isInteger(days) && days >= 0) {
      this.commit(days);
    }
  }

  <template>
    <div class="filter-navigation-token__editor --date">
      <EditorHeading @data={{@data}} />

      <section class="filter-navigation-token__date-section">
        <h3 class="filter-navigation-token__date-heading">
          {{i18n "filter.date_editor.relative"}}
        </h3>
        <label class="filter-navigation-token__custom-days">
          <span>{{i18n "filter.date_editor.custom_days"}}</span>
          <input
            class="filter-navigation-token__custom-days-input"
            inputmode="numeric"
            min="0"
            placeholder="14"
            type="number"
            value={{this.days}}
            {{on "input" (withEventValue this.updateDays)}}
            {{on "keydown" this.commitCustomDays}}
            {{didInsert this.focusDays}}
          />
        </label>
        {{#if this.daysHint}}
          <span class="filter-navigation-token__days-hint">
            {{this.daysHint}}
          </span>
        {{/if}}
      </section>

      <section class="filter-navigation-token__date-section">
        <h3 class="filter-navigation-token__date-heading">
          {{i18n "filter.date_editor.specific_date"}}
        </h3>
        <div
          class="filter-navigation-token__calendar date-picker-container"
          id={{this.calendarId}}
          {{didInsert this.calendarContainerInserted}}
        ></div>
        {{! the picker looks its container up by id, so it must be in the document first }}
        {{#if this.calendarReady}}
          {{! on desktop the inline calendar is the control; the field stays for screen readers }}
          <DDatePicker
            class={{dConcatClass
              "filter-navigation-token__date-input"
              (unless this.site.mobileView "sr-only")
            }}
            @containerId={{this.calendarId}}
            @maxDate={{this.maxDate}}
            @onSelect={{this.commit}}
            @value={{readonly this.selectedDate}}
          />
        {{/if}}
      </section>
    </div>
  </template>
}

class FilterTokenValueEditor extends Component {
  @service site;

  @tracked search = this.args.data.value || "";
  @tracked suggestions = [];
  @tracked selectedIndex = -1;

  requestId = 0;
  searchTimer = null;

  labelFor = (item) =>
    item.term ?? item.name.substring(this.queryPrefix.length);

  constructor() {
    super(...arguments);
    // open on the full list so another value is one click away, unless the
    // value already holds several entries that the search has to continue from
    const delimiters = this.args.data.delimiters || [];
    const isMultiValue = delimiters.some((d) => this.search.includes(d.name));
    this.fetchSuggestions(isMultiValue ? this.search : "");
  }

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.searchTimer);
  }

  get placeholder() {
    return i18n("filter.edit_token_placeholder", {
      name: this.args.data.filterName,
    });
  }

  get queryPrefix() {
    return `${this.args.data.prefix}${this.args.data.filterName}:`;
  }

  /**
   * The suggestions as listed, with an "exclude subcategories" row nested
   * under every category that has subcategories.
   */
  get items() {
    if (!this.args.data.isCategory) {
      return this.suggestions;
    }

    const covered = this.args.data.coveredCategoryIds;

    return this.suggestions
      .filter((item) => !item.category || !covered?.has(item.category.id))
      .flatMap((item) =>
        item.category?.subcategories?.length
          ? [
              item,
              {
                excludeSubcategories: true,
                category: item.category,
                term: item.term,
                level: (item.level || 0) + 1,
              },
            ]
          : [item]
      );
  }

  async fetchSuggestions(search = this.search) {
    const requestId = ++this.requestId;

    try {
      const result = await FilterSuggestions.getSuggestions(
        `${this.queryPrefix}${search}`,
        this.args.data.tips,
        { site: this.site }
      );

      if (requestId !== this.requestId) {
        return;
      }

      this.suggestions = (result.suggestions || []).filter((s) =>
        s.name.startsWith(this.queryPrefix)
      );
      this.selectedIndex = -1;
    } catch {
      // ignore fetch errors (rate limits, etc)
    }
  }

  @action
  updateSearch(value) {
    this.search = value;
    cancel(this.searchTimer);
    this.searchTimer = discourseDebounce(this, this.fetchSuggestions, 200);
  }

  @action
  focusInput(element) {
    element.focus();
    element.select();
  }

  @action
  selectSuggestion(suggestion) {
    if (this.args.data.isCategory && suggestion.category) {
      // `=` limits a category to itself; any `-` (exclude) is kept
      const prefix = this.args.data.prefix.replace("=", "");
      this.commit(
        suggestion.term,
        suggestion.excludeSubcategories ? `${prefix}=` : prefix
      );
      return;
    }

    const value = suggestion.name.substring(this.queryPrefix.length);
    const delimiters = this.args.data.delimiters || [];

    // a trailing delimiter means the user wants to keep adding values
    if (delimiters.some((d) => value.endsWith(d.name))) {
      this.updateSearch(value);
      return;
    }

    this.commit(value);
  }

  commit(value, prefix = this.args.data.prefix) {
    this.args.data.onCommit(value.trim(), prefix);
    this.args.close();
  }

  @action
  handleKeydown(event) {
    const count = this.items.length;

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        if (count) {
          this.selectedIndex = (this.selectedIndex + 1) % count;
        }
        break;
      case "ArrowUp":
        event.preventDefault();
        if (count) {
          this.selectedIndex =
            this.selectedIndex <= 0 ? count - 1 : this.selectedIndex - 1;
        }
        break;
      case "Enter":
        event.preventDefault();
        event.stopPropagation();
        if (this.selectedIndex >= 0 && this.items[this.selectedIndex]) {
          this.selectSuggestion(this.items[this.selectedIndex]);
        } else {
          this.commit(this.search);
        }
        break;
    }
  }

  <template>
    <div class="filter-navigation-token__editor">
      <EditorHeading @data={{@data}} />
      <input
        aria-label={{this.placeholder}}
        autocapitalize="none"
        autocomplete="off"
        autocorrect="off"
        class="filter-navigation-token__editor-input"
        placeholder={{this.placeholder}}
        type="text"
        value={{this.search}}
        {{on "input" (withEventValue this.updateSearch)}}
        {{on "keydown" this.handleKeydown}}
        {{didInsert this.focusInput}}
      />

      {{#if this.items.length}}
        <DDropdownMenu as |dropdown|>
          {{#each this.items as |item index|}}
            <dropdown.item
              class={{dConcatClass
                "filter-navigation__tip-item"
                (unless item.count "--stacked")
                (if item.level (concat "--level-" item.level))
                (if item.excludeSubcategories "--exclude-subcategories")
                (if (eq index this.selectedIndex) "--selected")
              }}
              {{on "click" (fn this.selectSuggestion item)}}
            >
              {{#if item.excludeSubcategories}}
                <span class="filter-navigation__exclude-subcategories">
                  {{dIcon "ban"}}
                  <span>{{i18n
                      "filter.category_token.exclude_subcategories"
                    }}</span>
                </span>
              {{else if item.category}}
                {{dCategoryBadge item.category allowUncategorized=true}}
              {{else}}
                <span class="filter-navigation__tip-name">
                  {{this.labelFor item}}
                </span>
                {{#if item.count}}
                  <span class="filter-navigation__tip-count">
                    {{item.count}}
                  </span>
                {{else if item.description}}
                  <span class="filter-navigation__tip-description">
                    {{item.description}}
                  </span>
                {{/if}}
              {{/if}}
            </dropdown.item>
          {{/each}}
        </DDropdownMenu>
      {{/if}}
    </div>
  </template>
}

/** Picks a value for one filter: a calendar for dates, otherwise a list. */
export const FilterTokenEditor = <template>
  {{#if @data.isDate}}
    <FilterTokenDateEditor @close={{@close}} @data={{@data}} />
  {{else}}
    <FilterTokenValueEditor @close={{@close}} @data={{@data}} />
  {{/if}}
</template>;

/**
 * A committed segment of the filter query rendered as a removable chip.
 * Filters (`name:value`) get a value picker; free text is edited inline.
 */
export default class FilterNavigationToken extends Component {
  get token() {
    return parseFilterToken(this.args.raw);
  }

  get isFilter() {
    return !!this.token.filterName;
  }

  get tip() {
    return FilterSuggestions.findTipForFilter(
      this.token.filterName,
      this.args.tips || []
    );
  }

  get isCategory() {
    return this.tip?.type === "category";
  }

  /** Every category in the value, or none if any slug is unknown. */
  get categories() {
    if (!this.isCategory || !this.token.value) {
      return [];
    }

    const categories = this.token.value.split(",").map(findCategory);
    return categories.every(Boolean) ? categories : [];
  }

  get includesSubcategories() {
    return !this.token.prefix.includes("=");
  }

  /** Descendants of the chosen categories, mirroring the server's lookup. */
  get subcategories() {
    const chosen = new Set(this.categories.map((c) => c.id));
    const found = new Map();

    for (const category of this.categories) {
      for (const descendant of category.descendants) {
        if (!chosen.has(descendant.id)) {
          found.set(descendant.id, descendant);
        }
      }
    }

    return [...found.values()];
  }

  /** "{badges} only", when subcategories exist but are left out. */
  get onlyLabel() {
    if (this.includesSubcategories || !this.subcategories.length) {
      return null;
    }

    const badges = this.categories
      // a link here would navigate away instead of opening the picker
      .map((c) =>
        categoryBadgeHTML(c, { allowUncategorized: true, link: false })
      )
      .join(", ");

    return trustHTML(
      i18n("filter.category_token.only", { categories: badges })
    );
  }

  /** The `=` modifier is spelled out by the label, so only `-` is shown. */
  get displayPrefix() {
    return this.isCategory
      ? this.token.prefix.replace("=", "")
      : this.token.prefix;
  }

  get icon() {
    if (!this.isFilter) {
      return null;
    }
    // the category badge already says what it is
    if (this.categories.length) {
      return null;
    }
    return iconForFilter(this.token.filterName, this.tip);
  }

  get displayValue() {
    return (
      literalLabel(this.token.filterName, this.token.value) ?? this.token.value
    );
  }

  get editorData() {
    return filterEditorData({
      filterName: this.token.filterName,
      prefix: this.token.prefix,
      value: this.token.value,
      tips: this.args.tips,
      tokens: this.args.tokens,
      index: this.args.index,
      onCommit: this.commitValue,
    });
  }

  get removeLabel() {
    return i18n("filter.remove_token", { token: this.args.raw });
  }

  get editLabel() {
    return i18n("filter.edit_token", { name: this.token.filterName });
  }

  @action
  commitValue(value, prefix = this.token.prefix) {
    if (!value) {
      this.args.onRemove();
      return;
    }

    this.args.onReplace(`${prefix}${this.token.filterName}:${value}`);
  }

  <template>
    <span
      class={{dConcatClass
        "filter-navigation-token"
        (if this.isFilter "--filter" "--text")
        (if this.token.prefix "--prefixed")
      }}
      data-filter={{this.token.filterName}}
      data-token={{@raw}}
      title={{@raw}}
    >
      {{#if this.isFilter}}
        {{#if (or this.icon this.displayPrefix)}}
          <span class="filter-navigation-token__name">
            {{#if this.displayPrefix}}
              <span class="filter-navigation-token__prefix">
                {{this.displayPrefix}}
              </span>
            {{/if}}
            {{#if this.icon}}
              {{dIcon this.icon}}
            {{/if}}
          </span>
        {{/if}}

        <DMenu
          @ariaLabel={{this.editLabel}}
          @arrow={{false}}
          @identifier="filter-navigation-token-editor"
          @onShow={{@onEditorShow}}
          @placement="bottom-start"
          @triggerClass="filter-navigation-token__value btn-transparent"
        >
          <:trigger>
            {{#if this.onlyLabel}}
              <span class="filter-navigation-token__category-only">
                {{this.onlyLabel}}
              </span>
            {{else if this.categories.length}}
              <span class="filter-navigation-token__categories">
                {{#each this.categories as |category|}}
                  {{dCategoryBadge category allowUncategorized=true}}
                {{/each}}
              </span>
            {{else if this.token.value}}
              {{this.displayValue}}
            {{else}}
              <span class="filter-navigation-token__value-placeholder">…</span>
            {{/if}}
          </:trigger>
          <:content as |menu|>
            <FilterTokenEditor
              @close={{menu.close}}
              @data={{this.editorData}}
            />
          </:content>
        </DMenu>
      {{else}}
        <button
          class="filter-navigation-token__text"
          type="button"
          {{on "click" @onEdit}}
        >
          {{@raw}}
        </button>
      {{/if}}

      <DButton
        class="filter-navigation-token__remove btn-transparent"
        @action={{@onRemove}}
        @icon="xmark"
        @translatedAriaLabel={{this.removeLabel}}
        @translatedTitle={{this.removeLabel}}
      />
    </span>
  </template>
}
