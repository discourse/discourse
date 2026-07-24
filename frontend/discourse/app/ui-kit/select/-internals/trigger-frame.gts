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
