import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { on } from "@ember/modifier";
import dIcon from "discourse/ui-kit/helpers/d-icon";

interface TriggerFrameSignature {
  Args: {
    /** The leading (decorative) trigger icon, or `undefined` for none. */
    icon?: string;
    /** The already-resolved caret icon (open/closed is decided by the parent). */
    caret: string;
    /** Whether to render the caret (the parent defaults this to `true`). */
    showCaret?: boolean;
    /** Whether to render the clear control (parent gates this on value + clearable + not locked). */
    showClear?: boolean;
    /** The clear control's accessible name (`"Clear selection"` / `"Clear all"`). */
    clearLabel?: string;
    /** Clears the whole selection; stops the click from toggling the overlay. */
    onClear?: (event: MouseEvent) => void;
    /** Focuses the control when a wrapping label forwards its activation to the sink. */
    onLabelActivate: (event: MouseEvent) => void;
  };
  Blocks: {
    /**
     * The variant-specific trigger middle — the multi chips + query input, the single
     * typeahead presentation + input, or the button/static value.
     */
    default: [];
  };
}

/**
 * The shared frame around every DSelect trigger variant: an optional leading icon, the
 * variant-specific middle (yielded), an optional trailing clear control, and the caret.
 * Everything is emitted as **siblings with no wrapping element** (a multi-root `<template>`),
 * so the trigger root's flex layout, `matchTriggerWidth`, and focus/containment behavior are
 * unchanged and the delicate typeahead input subtree (rendered inside the yielded block) is
 * never nested a level deeper.
 *
 * The `{{yield}}` MUST stay free of surrounding control flow: a conditional wrapped around it
 * would tear down and re-insert the query input on toggle, disturbing focus and the roving
 * controller registered against that element. The leading icon and trailing clear sit
 * before/after the yield, never around it.
 */
const TriggerFrame: TemplateOnlyComponent<TriggerFrameSignature> = <template>
  {{! Absorbs the click a wrapping label forwards into the trigger.

    A label activates its first labelable descendant, which would otherwise be whichever control
    comes first: a chip's remove button on a multi-select, or the clear button on the variants
    whose value renders as a span. Clicking a field's caption would then silently drop a
    selection.

    Keep it first — tree order is the whole mechanism, and it is what lets a control added here
    later skip a click guard of its own. Having taken the association it owes the field what a
    label normally does, so the forwarded click is handed on as a focus rather than swallowed.

    It carries no name, so it is never submitted with a form, and the display is what keeps it
    unfocusable and untabbable; hidden keeps it out of the accessibility tree. That display is
    inline rather than in a stylesheet because the trigger is a flex row with a gap, so even a
    zero-size rendered child shifts the layout, and a stylesheet would make that depend on load
    order and on no theme overriding it. }}

  <input
    type="text"
    class="d-combobox__label-sink"
    style="display: none"
    hidden
    {{on "click" @onLabelActivate}}
  />
  {{#if @icon}}
    {{dIcon @icon class="d-combobox__leading-icon"}}
  {{/if}}
  {{yield}}
  {{#if @showClear}}
    <button
      type="button"
      class="d-combobox__clear"
      {{! Not a tab stop: a pointer affordance only. Keyboard users clear via Backspace/Delete,
        handled by the parent on the input / control trigger. }}
      tabindex="-1"
      aria-label={{@clearLabel}}
      {{on "click" @onClear}}
    >
      {{dIcon "xmark"}}
    </button>
  {{/if}}
  {{#if @showCaret}}
    {{dIcon @caret class="d-combobox__caret"}}
  {{/if}}
</template>;

export default TriggerFrame;
