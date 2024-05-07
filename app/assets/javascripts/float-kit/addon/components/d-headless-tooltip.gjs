import { and } from "truth-helpers";
import DInlineFloat from "float-kit/components/d-inline-float";

const DHeadlessTooltip = <template>
  <DInlineFloat
    @instance={{@tooltip}}
    @trapTab={{and @tooltip.options.interactive @tooltip.options.trapTab}}
    @mainClass="fk-d-tooltip"
    @innerClass="fk-d-tooltip__inner-content"
    @role="tooltip"
    @inline={{@inline}}
  />
</template>;

export default DHeadlessTooltip;
