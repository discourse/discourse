import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import FilterNavigationToken, {
  filterEditorData,
  FilterTokenEditor,
} from "discourse/components/discovery/filter-navigation-token";
import DMenu from "discourse/float-kit/components/d-menu";
import withEventValue from "discourse/helpers/with-event-value";
import { splitFilterQuery } from "discourse/lib/filter-query-tokens";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

// most used first: where, what, who, then state, time and activity counts
const FILTER_ORDER = [
  "category",
  "tag",
  "group",
  "users",
  "created-by",
  "status",
  "in",
  "created-after",
  "activity-after",
  "order",
  "tag-group",
  "latest-post-after",
  "created-before",
  "activity-before",
  "latest-post-before",
  "likes-min",
  "posts-min",
  "views-min",
  "posters-min",
  "likes-op-min",
  "likes-max",
  "posts-max",
  "views-max",
  "posters-max",
  "likes-op-max",
  "bookmarked-after",
  "bookmarked-before",
  "locale",
  "topic",
];

class AddFilterMenu extends Component {
  @tracked search = "";
  @tracked selectedIndex = 0;

  /** The filter picked from the list, whose values now take its place. */
  @tracked chosen = null;

  labelFor = (tip) => tip.name.replace(/:$/, "");

  get editorData() {
    return filterEditorData({
      filterName: this.labelFor(this.chosen),
      tips: this.args.tips,
      tokens: this.args.tokens,
      onCommit: this.commit,
      onBack: this.backToFilters,
    });
  }

  get filters() {
    const search = this.search.trim().toLowerCase();

    return this.args.filters.filter(
      (tip) =>
        !search ||
        tip.name.includes(search) ||
        tip.description?.toLowerCase().includes(search)
    );
  }

  @action
  updateSearch(value) {
    this.search = value;
    this.selectedIndex = 0;
  }

  @action
  choose(tip) {
    this.chosen = tip;
  }

  @action
  commit(value, prefix) {
    if (value) {
      this.args.onAdd(`${prefix}${this.labelFor(this.chosen)}:${value}`);
    }
  }

  @action
  backToFilters() {
    this.chosen = null;
  }

  @action
  focusInput(element) {
    element.focus();
  }

  @action
  handleKeydown(event) {
    const count = this.filters.length;

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
        if (this.filters[this.selectedIndex]) {
          this.choose(this.filters[this.selectedIndex]);
        }
        break;
    }
  }

  <template>
    {{#if this.chosen}}
      <FilterTokenEditor @close={{@close}} @data={{this.editorData}} />
    {{else}}
      <div class="filter-navigation-builder__menu">
        <input
          aria-label={{i18n "filter.search_filters"}}
          autocapitalize="none"
          autocomplete="off"
          autocorrect="off"
          class="filter-navigation-builder__menu-search"
          placeholder={{i18n "filter.search_filters"}}
          type="text"
          value={{this.search}}
          {{on "input" (withEventValue this.updateSearch)}}
          {{on "keydown" this.handleKeydown}}
          {{didInsert this.focusInput}}
        />

        <DDropdownMenu as |dropdown|>
          {{#each this.filters as |tip index|}}
            <dropdown.item
              class={{dConcatClass
                "filter-navigation__tip-item"
                "--stacked"
                (if (eq index this.selectedIndex) "--selected")
              }}
              data-filter={{tip.name}}
              {{on "click" (fn this.choose tip)}}
            >
              <span class="filter-navigation__tip-name">
                {{this.labelFor tip}}
              </span>
              {{#if tip.description}}
                <span class="filter-navigation__tip-description">
                  {{tip.description}}
                </span>
              {{/if}}
            </dropdown.item>
          {{/each}}

          {{#if @onEditAsText}}
            <dropdown.divider />

            <dropdown.item class="filter-navigation-builder__edit-as-text">
              <DButton
                class="btn-transparent"
                @action={{@onEditAsText}}
                @icon="pencil"
                @label="filter.edit_as_text"
              />
            </dropdown.item>
          {{/if}}
        </DDropdownMenu>
      </div>
    {{/if}}
  </template>
}

/**
 * Shows the filter query as a row of tokens with an "Add filter" button,
 * for people who would rather not type the query syntax.
 */
export default class FilterNavigationBuilder extends Component {
  @tracked tokens = splitFilterQuery(this.args.initialInputValue);

  get filters() {
    const rank = (tip) => {
      const index = FILTER_ORDER.indexOf(tip.name.replace(/:$/, ""));
      return index === -1 ? FILTER_ORDER.length : index;
    };

    // unlisted filters (e.g. from plugins) follow, priority ones first
    return (this.args.tips || [])
      .filter((tip) => tip.name.endsWith(":"))
      .sort(
        (a, b) =>
          rank(a) - rank(b) ||
          (a.priority === 1 ? 0 : 1) - (b.priority === 1 ? 0 : 1) ||
          a.name.localeCompare(b.name)
      );
  }

  get hasChips() {
    return this.tokens.length > 0;
  }

  // spelled out until there is something to compare the bare "+" against
  get addLabel() {
    return this.hasChips ? null : i18n("filter.add_filter");
  }

  @action
  syncFromInitialValue() {
    const incoming = splitFilterQuery(this.args.initialInputValue);

    if (incoming.join(" ") !== this.tokens.join(" ")) {
      this.tokens = incoming;
    }
  }

  @action
  addToken(raw) {
    this.tokens = [...this.tokens, raw];
    this.#submit();
  }

  @action
  removeToken(index) {
    this.tokens = this.tokens.filter((_, i) => i !== index);
    this.#submit();
  }

  @action
  replaceToken(index, raw) {
    this.tokens = this.tokens.map((token, i) => (i === index ? raw : token));
    this.#submit();
  }

  @action
  editAsText() {
    this.args.onEditAsText?.();
  }

  @action
  editAsTextFromMenu(close) {
    close();
    this.args.onEditAsText();
  }

  #submit() {
    this.args.onChange(this.tokens.join(" "), true);
  }

  <template>
    <div
      class="filter-navigation-builder"
      {{didUpdate this.syncFromInitialValue @initialInputValue}}
    >
      {{#each this.tokens as |raw index|}}
        <FilterNavigationToken
          @index={{index}}
          @onEdit={{this.editAsText}}
          @onRemove={{fn this.removeToken index}}
          @onReplace={{fn this.replaceToken index}}
          @raw={{raw}}
          @tips={{@tips}}
          @tokens={{this.tokens}}
        />
      {{/each}}

      <DMenu
        @ariaLabel={{i18n "filter.add_filter"}}
        @arrow={{false}}
        @icon="filter"
        @identifier="filter-navigation-builder-add"
        @label={{this.addLabel}}
        @placement="bottom-start"
        @title={{i18n "filter.add_filter"}}
        @triggerClass={{dConcatClass
          "filter-navigation-builder__add btn-default"
          (if this.hasChips "btn-icon no-text" "btn-icon-text")
        }}
      >
        <:content as |menu|>
          <AddFilterMenu
            @close={{menu.close}}
            @filters={{this.filters}}
            @onAdd={{this.addToken}}
            @onEditAsText={{if
              @onEditAsText
              (fn this.editAsTextFromMenu menu.close)
            }}
            @tips={{@tips}}
            @tokens={{this.tokens}}
          />
        </:content>
      </DMenu>

    </div>
  </template>
}
