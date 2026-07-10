import type { TemplateOnlyComponent } from "@ember/component/template-only";
import DInlineFloat from "discourse/float-kit/components/d-inline-float";
import type DTooltipInstance from "discourse/float-kit/lib/d-tooltip-instance";
import { and } from "discourse/truth-helpers";

interface DHeadlessTooltipSignature {
  Args: {
    tooltip: DTooltipInstance;
    inline?: boolean | null;
  };
}

const DHeadlessTooltip: TemplateOnlyComponent<DHeadlessTooltipSignature> =
  <template>
    <DInlineFloat
      @instance={{@tooltip}}
      @trapTab={{and @tooltip.options.interactive @tooltip.options.trapTab}}
      @mainClass="fk-d-tooltip__content"
      @innerClass="fk-d-tooltip__inner-content"
      @role="tooltip"
      @inline={{@inline}}
    />
  </template>;

export default DHeadlessTooltip;
