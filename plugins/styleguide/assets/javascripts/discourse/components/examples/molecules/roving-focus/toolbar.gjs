import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";

const TOGGLES = ["bold", "italic", "underline"];

const COMMANDS = [
  { id: "copy" },
  { id: "cut", disabled: true },
  { id: "paste", ariaDisabled: true },
];

/**
 * Mirrors https://www.w3.org/WAI/ARIA/apg/patterns/toolbar/
 *
 * The APG toolbar pattern in plain semantic HTML: the whole bar is one tab stop, the arrows move
 * between controls, and Home/End reach the ends.
 *
 * Activation is deliberately not wired. The modifier only calls preventDefault on Enter and
 * Space when a consumer passes onActivate, so leaving it off lets the native buttons keep their
 * own activation, which is what a real toolbar wants.
 *
 * Entry is pinned to the first control because that is the toolbar convention, and it is the one
 * pattern where a marked item must NOT win: a button marking the current view would otherwise
 * take the tab stop away from the first.
 *
 * The last two commands spell disabled differently on purpose, and under this policy they behave
 * differently: the natively disabled one is skipped because the platform will not focus it,
 * while the aria-disabled one keeps its place in the sequence. Moving focus to a control is how
 * a screen reader user discovers it exists, so the second stays reachable without ever becoming
 * operable.
 */
export default class RovingFocusToolbarExample extends Component {
  @tracked pressed = {};

  get toggles() {
    return TOGGLES.map((id) => ({
      id,
      label: i18n(`styleguide.sections.roving_focus.toolbar.${id}`),
      pressed: this.pressed[id] ? "true" : "false",
    }));
  }

  get commands() {
    return COMMANDS.map((command) => ({
      ...command,
      label: i18n(`styleguide.sections.roving_focus.toolbar.${command.id}`),
      ariaDisabled: command.ariaDisabled ? "true" : undefined,
    }));
  }

  @action
  toggle(id) {
    this.pressed = { ...this.pressed, [id]: !this.pressed[id] };
  }

  <template>
    <div
      class="roving-demo__toolbar"
      role="toolbar"
      aria-label={{i18n "styleguide.sections.roving_focus.toolbar.label"}}
      {{dRovingFocus
        orientation="horizontal"
        itemSelector=".roving-demo__item"
        entryFocus="first"
        disabledItems="focusable"
      }}
    >
      {{#each this.toggles key="id" as |item|}}
        {{! eslint-disable-next-line ember/template-no-nested-interactive }}
        <button
          type="button"
          class="roving-demo__item"
          aria-pressed={{item.pressed}}
          {{on "click" (fn this.toggle item.id)}}
        >{{item.label}}</button>
      {{/each}}

      <span
        class="roving-demo__separator"
        role="separator"
        aria-orientation="vertical"
      ></span>

      {{#each this.commands key="id" as |command|}}
        {{! eslint-disable-next-line ember/template-no-nested-interactive }}
        <button
          type="button"
          class="roving-demo__item"
          disabled={{command.disabled}}
          aria-disabled={{command.ariaDisabled}}
        >{{command.label}}</button>
      {{/each}}

      {{! eslint-disable-next-line ember/template-no-nested-interactive }}
      <a class="roving-demo__item" href="https://www.w3.org/WAI/ARIA/apg/">
        {{i18n "styleguide.sections.roving_focus.toolbar.docs"}}
      </a>
    </div>
  </template>
}
