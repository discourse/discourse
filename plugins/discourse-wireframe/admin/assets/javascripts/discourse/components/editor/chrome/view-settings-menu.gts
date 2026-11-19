import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { on } from "@ember/modifier";
import { type ComponentLike } from "@glint/template";
import DMenu from "discourse/float-kit/components/d-menu";
import DToggleSwitchUntyped from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";

// TODO(devxp-typescript-pending): drop once d-toggle-switch is authored in .gts
// with a real Signature. Declaring its Element lets `{{on}}` attach to the
// switch, which spreads `...attributes` onto its inner button.
const DToggleSwitch = DToggleSwitchUntyped as unknown as ComponentLike<{
  /** Toggle state and label configuration. */
  Args: {
    /** Whether the toggle is enabled. */
    state?: boolean;
    /** Translation key naming the toggle. */
    label?: string;
  };
  /** Button element receiving splatted attributes. */
  Element: HTMLButtonElement;
}>;

interface ViewSettingsMenuSignature {
  /** Preference state and action owned by the editor shell. */
  Args: {
    /** Current dim preference reflected by the toggle. */
    dimNonEditable?: boolean;
    /** Flips the dim preference on the shell. */
    onToggleDim: () => void;
  };
}

/**
 * The toolbar's settings button: a dropdown holding how the canvas is shown.
 * The preference stays owned by the shell, which persists it; the menu only
 * reflects and forwards it.
 */
const ViewSettingsMenu: TemplateOnlyComponent<ViewSettingsMenuSignature> =
  <template>
    <DMenu
      @icon="gear"
      @identifier="wireframe-view-settings"
      @placement="bottom-end"
      @title={{i18n "wireframe.chrome.view_menu"}}
      @triggerClass="btn-flat wireframe-view-toggle"
    >
      <:content>
        <div class="wireframe-view-settings">
          <DToggleSwitch
            @label="wireframe.chrome.dim_non_editable_title"
            @state={{@dimNonEditable}}
            {{on "click" @onToggleDim}}
          />
          <p class="wireframe-view-settings__description">
            {{i18n "wireframe.chrome.dim_non_editable_description"}}
          </p>
        </div>
      </:content>
    </DMenu>
  </template>;

export default ViewSettingsMenu;
