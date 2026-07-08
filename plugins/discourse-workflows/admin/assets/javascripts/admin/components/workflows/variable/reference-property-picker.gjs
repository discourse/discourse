import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ReferencePropertyPicker extends Component {
  @tracked query = "";
  @tracked activeIndex = 0;
  listElement;

  constructor() {
    super(...arguments);
    const current = this.args.data?.current;
    const properties = this.args.data?.properties || [];
    const index = current
      ? properties.findIndex((property) => property.name === current)
      : -1;
    this.activeIndex = index >= 0 ? index : 0;
  }

  get current() {
    return this.args.data?.current;
  }

  get hasProperties() {
    return (this.args.data?.properties || []).length > 0;
  }

  get filteredProperties() {
    const query = this.query.trim().toLowerCase();
    const properties = this.args.data?.properties || [];
    if (!query) {
      return properties;
    }
    return properties.filter((property) =>
      property.name.toLowerCase().includes(query)
    );
  }

  @action
  focusFilter(element) {
    // Next frame, so focus wins over the editor reclaiming it.
    requestAnimationFrame(() => {
      if (!this.isDestroying && !this.isDestroyed) {
        element.focus();
      }
    });
  }

  @action
  registerList(element) {
    this.listElement = element;
    this.scrollActiveIntoView();
  }

  @action
  updateQuery(event) {
    this.query = event.target.value;
    this.activeIndex = 0;
  }

  @action
  setActive(index) {
    this.activeIndex = index;
  }

  @action
  onKeydown(event) {
    const lastIndex = this.filteredProperties.length - 1;
    if (lastIndex < 0) {
      return;
    }

    if (event.key === "ArrowDown") {
      event.preventDefault();
      this.activeIndex =
        this.activeIndex >= lastIndex ? 0 : this.activeIndex + 1;
      this.scrollActiveIntoView();
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      this.activeIndex =
        this.activeIndex <= 0 ? lastIndex : this.activeIndex - 1;
      this.scrollActiveIntoView();
    } else if (event.key === "Enter") {
      event.preventDefault();
      const property = this.filteredProperties[this.activeIndex];
      if (property) {
        this.select(property.name);
      }
    }
  }

  scrollActiveIntoView() {
    this.listElement
      ?.querySelector(".workflows-reference-picker__option.--active")
      ?.scrollIntoView({ block: "nearest" });
  }

  @action
  select(name) {
    this.args.data?.onSelect?.(name);
  }

  @action
  edit() {
    this.args.data?.onEdit?.();
  }

  <template>
    <div class="workflows-reference-picker">
      <div class="workflows-reference-picker__header">
        {{#if this.hasProperties}}
          <input
            type="text"
            class="workflows-reference-picker__filter"
            placeholder={{i18n
              "discourse_workflows.reference_pill.filter_placeholder"
            }}
            aria-label={{i18n
              "discourse_workflows.reference_pill.filter_placeholder"
            }}
            {{didInsert this.focusFilter}}
            {{on "input" this.updateQuery}}
            {{on "keydown" this.onKeydown}}
          />
        {{else}}
          <span class="workflows-reference-picker__unavailable">
            {{i18n "discourse_workflows.reference_pill.no_properties"}}
          </span>
        {{/if}}

        <button
          type="button"
          class="workflows-reference-picker__edit"
          {{on "click" this.edit}}
        >
          {{dIcon "code"}}
          <span>{{i18n
              "discourse_workflows.reference_pill.edit_as_code"
            }}</span>
        </button>
      </div>

      {{#if this.hasProperties}}
        <ul
          class="workflows-reference-picker__list"
          {{didInsert this.registerList}}
        >
          {{#each this.filteredProperties as |property index|}}
            <li>
              <button
                type="button"
                class={{dConcatClass
                  "workflows-reference-picker__option"
                  (if (eq index this.activeIndex) "--active")
                  (if (eq property.name this.current) "--current")
                }}
                {{on "click" (fn this.select property.name)}}
                {{on "mouseenter" (fn this.setActive index)}}
              >
                <span class="workflows-reference-picker__name">
                  {{property.name}}
                </span>
                <span class="workflows-reference-picker__type">
                  {{property.type}}
                </span>
              </button>
            </li>
          {{else}}
            <li class="workflows-reference-picker__empty">
              {{i18n "discourse_workflows.reference_pill.no_matches"}}
            </li>
          {{/each}}
        </ul>
      {{/if}}
    </div>
  </template>
}
