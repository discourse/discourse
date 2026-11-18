import type { TOC } from "@ember/component/template-only";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";

interface DRelativeDateSignature {
  Args: {
    /** The date to show relative to now. It keeps updating, with the full date as its tooltip. */
    date: string | number | Date;
  };
}

const DRelativeDate: TOC<DRelativeDateSignature> = <template>
  {{~dAgeWithTooltip @date~}}
</template>;

export default DRelativeDate;
