// @ts-check
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dCloseOnClickOutside from "discourse/ui-kit/modifiers/d-close-on-click-outside";
import { i18n } from "discourse-i18n";
import SimulationControls from "discourse/plugins/discourse-wireframe/discourse/components/editor/simulation/simulation-controls";

/**
 * The editor's "View" surface: a right-docked drawer holding the controls for
 * how the canvas is shown — the dim-non-editable toggle plus the persona /
 * viewport simulation controls.
 *
 * Modeled on the publish review drawer (`publish-review-drawer.gjs`): a
 * `position: fixed` panel gated on `@isOpen`, so placement is exact rather than
 * fighting a floating overlay's collision padding. Clicking outside closes it —
 * the toolbar's View toggle is excluded so re-clicking it toggles rather than
 * close-then-reopens.
 *
 * The `dimNonEditable` preference stays owned by the shell (which persists it);
 * this drawer only reflects and forwards it. `SimulationControls` owns the
 * persona / viewport pickers and drives the `wireframeSimulation` service.
 *
 * Args:
 *   - `@isOpen` (boolean) — whether the drawer is shown.
 *   - `@dimNonEditable` (boolean) — current dim preference (reflected by the toggle).
 *   - `@onToggleDim` (`() => void`) — flips that preference on the shell.
 *   - `@onClose` (`() => void`) — closes the drawer.
 */
const ViewDrawer = <template>
  {{#if @isOpen}}
    <div
      class="wireframe-view-drawer wireframe-editor-overlay"
      role="dialog"
      aria-label={{i18n "wireframe.chrome.view_menu"}}
      {{dCloseOnClickOutside
        @onClose
        (hash targetSelector=".wireframe-view-toggle")
      }}
    >
      <div class="wireframe-view-drawer__header">
        <span class="wireframe-view-drawer__title">
          {{dIcon "sliders"}}
          <span>{{i18n "wireframe.chrome.view_menu"}}</span>
        </span>
        <DButton
          class="btn-flat wireframe-view-drawer__close"
          @icon="xmark"
          @ariaLabel="wireframe.chrome.view_close"
          @action={{@onClose}}
        />
      </div>

      <div class="wireframe-view-drawer__body">
        <div class="wireframe-view-drawer__dim">
          <DToggleSwitch
            @state={{@dimNonEditable}}
            @label="wireframe.chrome.dim_non_editable_title"
            {{on "click" @onToggleDim}}
          />
          <p class="wireframe-view-drawer__dim-description">
            {{i18n "wireframe.chrome.dim_non_editable_description"}}
          </p>
        </div>
        <SimulationControls />
      </div>
    </div>
  {{/if}}
</template>;

export default ViewDrawer;
