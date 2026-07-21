import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { type ComponentLike, type ModifierLike } from "@glint/template";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitchUntyped from "discourse/ui-kit/d-toggle-switch";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dCloseOnClickOutsideUntyped from "discourse/ui-kit/modifiers/d-close-on-click-outside";
import { i18n } from "discourse-i18n";
import SimulationControls from "discourse/plugins/discourse-wireframe/discourse/components/editor/simulation/simulation-controls";

// TODO(devxp-typescript-pending): drop once d-toggle-switch is authored in .gts
// with a real Signature, then import it directly. Untyped .gjs today gives no
// arg/attr types, so declaring its Element here lets the `{{on}}` modifier
// attach to the switch (it spreads `...attributes` onto its inner button).
const DToggleSwitch = DToggleSwitchUntyped as unknown as ComponentLike<{
  Args: { state?: boolean; label?: string; translatedLabel?: string };
  Element: HTMLButtonElement;
}>;

// TODO(devxp-typescript-pending): drop once d-close-on-click-outside is authored
// in .ts with a real Signature. Its DefaultSignature rejects the positional
// close callback plus the options hash, so its positional contract is declared
// here.
const dCloseOnClickOutside =
  dCloseOnClickOutsideUntyped as unknown as ModifierLike<{
    Element: HTMLElement;
    Args: {
      Positional: [
        close: () => void,
        options?: {
          targetSelector?: string;
          secondaryTargetSelector?: string;
          target?: Element;
        },
      ];
    };
  }>;

interface ViewDrawerSignature {
  Args: {
    // Whether the drawer is shown.
    isOpen?: boolean;
    // Current dim preference, reflected by the toggle.
    dimNonEditable?: boolean;
    // Flips the dim preference on the shell.
    onToggleDim: () => void;
    // Closes the drawer.
    onClose: () => void;
  };
  Element: HTMLDivElement;
}

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
 */
const ViewDrawer: TemplateOnlyComponent<ViewDrawerSignature> = <template>
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
