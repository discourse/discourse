import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface DButtonTooltipSignature {
  Element: HTMLDivElement;
  Blocks: {
    /** The action button, rendered first. */
    button: [];

    /**
     * The tooltip trigger rendered next to the button, typically a
     * `<DTooltip />`. It is often shown conditionally, e.g. an info icon that
     * appears only while the button is disabled to explain why.
     */
    tooltip: [];
  };
}

/**
 * Lays out an action button beside a tooltip trigger so the two sit inline
 * together, sharing a single wrapper. This keeps a button and an adjacent
 * explanatory tooltip aligned without the caller styling the pairing itself.
 */
const DButtonTooltip: TemplateOnlyComponent<DButtonTooltipSignature> =
  <template>
    <div class="fk-d-button-tooltip" ...attributes>
      {{yield to="button"}}
      {{yield to="tooltip"}}
    </div>
  </template>;

export default DButtonTooltip;
