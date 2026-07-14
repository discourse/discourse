// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/**
 * Editor prompt painted over a block whose identifying arg is unset — the "pick
 * a topic to feature" style call to action. It fills the block chrome and,
 * when activated, selects the block so its inspector opens for the author to
 * fill the arg in. The prompt text comes from the arg's `ui.emptyPrompt`, so
 * the block itself never carries editor-facing copy on its render path.
 *
 * Args:
 *   - `@prompt` (string) — the pre-translated call to action to display and
 *     the button's accessible name.
 *   - `@icon` (string) — an icon id shown above the prompt (typically the
 *     block's own icon).
 *   - `@onActivate` (`() => void`) — fired on click / Enter / Space. The click
 *     stops propagation, so the owner wires this to select the block itself
 *     (the surrounding chrome's own selection handler never runs).
 */
export default class EmptyArgPrompt extends Component {
  @action
  activate(event) {
    // Stop the chrome's own click selection from also firing; we select the
    // block ourselves so the behaviour matches a normal block selection.
    event?.stopPropagation?.();
    event?.preventDefault?.();
    this.args.onActivate?.();
  }

  <template>
    <button
      type="button"
      class="wireframe-empty-arg-prompt"
      aria-label={{@prompt}}
      {{on "click" this.activate}}
    >
      {{#if @icon}}
        <span class="wireframe-empty-arg-prompt__icon">{{dIcon @icon}}</span>
      {{/if}}
      <span class="wireframe-empty-arg-prompt__label">{{@prompt}}</span>
    </button>
  </template>
}
