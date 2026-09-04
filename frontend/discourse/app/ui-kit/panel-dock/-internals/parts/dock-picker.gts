import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import booleanString from "discourse/helpers/boolean-string";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import {
  type DockSide,
  SIDES,
} from "discourse/ui-kit/panel-dock/-internals/sides";
import { i18n } from "discourse-i18n";

interface DockPickerSignature {
  /** The group wrapping the side buttons. */
  Element: HTMLDivElement;
  Args: {
    /** Whether the panel is currently docked against the given side. */
    isSide: (side: DockSide) => boolean;

    /** Called with the side the user picks. */
    onSelect: (side: DockSide) => void;

    /** Whether the panel is currently in a window of its own. */
    isWindowed?: () => boolean;

    /**
     * Called when the user asks for the panel to move into its own window.
     * Omitting it leaves the choice out, for a panel that cannot.
     */
    onSelectWindow?: () => void;
  };
}

/**
 * The control that moves a docked panel between viewport edges.
 *
 * It is a part rather than markup inside the chassis so that a caller who
 * takes over the panel's whole interior through the `main` block can still
 * place it, inside a header row of their own.
 */
const DockPicker: TemplateOnlyComponent<DockPickerSignature> = <template>
  <div
    class="d-panel-dock__dock-picker"
    role="group"
    aria-label={{i18n "panel_dock.dock"}}
    ...attributes
  >
    {{#each SIDES as |side|}}
      <button
        type="button"
        class={{dConcatClass "d-panel-dock__dock-button" (concat "--" side)}}
        aria-pressed={{booleanString (@isSide side) omitFalse=false}}
        aria-label={{i18n (concat "panel_dock.dock_" side)}}
        title={{i18n (concat "panel_dock.dock_" side)}}
        {{on "click" (fn @onSelect side)}}
      >
        <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">
          <rect
            x="1.5"
            y="2.5"
            width="13"
            height="11"
            rx="1.5"
            stroke="currentColor"
            fill="none"
            stroke-width="1.5"
          />
          {{#if (eq side "start")}}
            <rect
              x="3"
              y="4"
              width="4"
              height="8"
              rx="0.5"
              fill="currentColor"
            />
          {{else if (eq side "end")}}
            <rect
              x="9"
              y="4"
              width="4"
              height="8"
              rx="0.5"
              fill="currentColor"
            />
          {{else}}
            <rect
              x="3"
              y="8"
              width="10"
              height="4"
              rx="0.5"
              fill="currentColor"
            />
          {{/if}}
        </svg>
      </button>
    {{/each}}

    {{#if @onSelectWindow}}
      <button
        type="button"
        class={{dConcatClass "d-panel-dock__dock-button" "--window"}}
        aria-pressed={{booleanString (@isWindowed) omitFalse=false}}
        aria-label={{i18n "panel_dock.dock_window"}}
        title={{i18n "panel_dock.dock_window"}}
        {{on "click" @onSelectWindow}}
      >
        <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">
          <rect
            x="1.5"
            y="4.5"
            width="9"
            height="7"
            rx="1.5"
            stroke="currentColor"
            fill="none"
            stroke-width="1.5"
          />
          <rect
            x="6.5"
            y="2.5"
            width="8"
            height="6"
            rx="1.5"
            stroke="currentColor"
            fill="var(--secondary)"
            stroke-width="1.5"
          />
        </svg>
      </button>
    {{/if}}
  </div>
</template>;

export default DockPicker;
