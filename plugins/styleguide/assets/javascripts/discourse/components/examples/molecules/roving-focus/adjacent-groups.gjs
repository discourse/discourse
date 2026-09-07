import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";

const FILTERS = ["open", "mine", "recent"];

/**
 * A group that is NOT a tab stop, sitting beside a control that is.
 *
 * Tab reaches the field and nothing else: the filters are not in the tab sequence at all, which
 * is what `tabStop=false` means and why the whole arrangement counts as one component rather
 * than two. Reaching the filters is a step from the field, and running off their end is a step
 * back to it.
 *
 * That return trip is what the boundary report is for. The modifier says the cursor tried to
 * leave and in which direction; it does not decide where to send it, because only this component
 * knows the field is there. The direction is logical, so this keeps working in a right-to-left
 * locale. Entry resolves the field's computed direction too, so its caret-facing arrow mirrors
 * with the return trip.
 */
export default class RovingFocusAdjacentGroupsExample extends Component {
  @tracked active = ["open"];
  @tracked filterApi = null;
  @tracked field = null;

  get filters() {
    return FILTERS.map((id) => ({
      id,
      label: i18n(`styleguide.sections.roving_focus.adjacent.${id}`),
      pressed: this.active.includes(id) ? "true" : "false",
    }));
  }

  @action
  captureField(element) {
    this.field = element;
  }

  @action
  enterFilters(event) {
    const entryKey =
      getComputedStyle(event.target).direction === "rtl"
        ? "ArrowRight"
        : "ArrowLeft";

    // Only from the very start of the text, so the arrow keeps its caret meaning everywhere else.
    if (event.key === entryKey && event.target.selectionStart === 0) {
      event.preventDefault();
      this.filterApi?.focusLast();
    }
  }

  @action
  leaveFilters(direction) {
    if (direction === "forward") {
      this.field?.focus();
    }
  }

  @action
  registerFilters(api) {
    this.filterApi = api;
  }

  @action
  toggle(id) {
    this.active = this.active.includes(id)
      ? this.active.filter((entry) => entry !== id)
      : [...this.active, id];
  }

  <template>
    <div class="roving-demo__adjacent">
      <div
        class="roving-demo__filters"
        role="group"
        aria-label={{i18n "styleguide.sections.roving_focus.adjacent.label"}}
        {{dRovingFocus
          orientation="horizontal"
          itemSelector=".roving-demo__filter"
          tabStop=false
          onBoundary=this.leaveFilters
          onRegisterApi=this.registerFilters
        }}
      >
        {{#each this.filters key="id" as |filter|}}
          <button
            type="button"
            class="roving-demo__filter"
            aria-pressed={{filter.pressed}}
            {{on "click" (fn this.toggle filter.id)}}
          >{{filter.label}}</button>
        {{/each}}
      </div>

      <input
        class="roving-demo__field"
        type="text"
        aria-label={{i18n "styleguide.sections.roving_focus.adjacent.field"}}
        placeholder={{i18n
          "styleguide.sections.roving_focus.adjacent.placeholder"
        }}
        {{didInsert this.captureField}}
        {{on "keydown" this.enterFilters}}
      />
    </div>
  </template>
}
