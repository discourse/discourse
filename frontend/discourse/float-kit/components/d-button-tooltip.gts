import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface DButtonTooltipSignature {
  Element: HTMLDivElement;
  Blocks: {
    /** The button. */
    button: [];

    /** The tooltip content shown for the button. */
    tooltip: [];
  };
}

const DButtonTooltip: TemplateOnlyComponent<DButtonTooltipSignature> =
  <template>
    <div class="fk-d-button-tooltip" ...attributes>
      {{yield to="button"}}
      {{yield to="tooltip"}}
    </div>
  </template>;

export default DButtonTooltip;
