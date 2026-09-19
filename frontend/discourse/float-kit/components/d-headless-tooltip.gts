import type { TemplateOnlyComponent } from "@ember/component/template-only";
import DInlineFloat from "discourse/float-kit/components/d-inline-float";
import type DTooltipInstance from "discourse/float-kit/lib/d-tooltip-instance";
import { and } from "discourse/truth-helpers";

interface DHeadlessTooltipSignature {
  Args: {
    /** The tooltip instance to render. */
    tooltip: DTooltipInstance;

    /** Whether to render in place instead of into the portal outlet. */
    inline?: boolean | null;
  };
}

/**
 * Renders a tooltip instance created through the `tooltip` service, whose
 * trigger lives elsewhere in the DOM rather than being owned by this component.
 * It is mounted once by `DTooltips` at the app root, which iterates every
 * registered tooltip with a detached trigger. Compare `DTooltip`, the
 * declarative component that owns both its trigger and its instance.
 */
const DHeadlessTooltip: TemplateOnlyComponent<DHeadlessTooltipSignature> =
  <template>
    <DInlineFloat
      @inline={{@inline}}
      @innerClass="fk-d-tooltip__inner-content"
      @instance={{@tooltip}}
      @mainClass="fk-d-tooltip__content"
      @role="tooltip"
      @trapTab={{and @tooltip.options.interactive @tooltip.options.trapTab}}
    />
  </template>;

export default DHeadlessTooltip;
