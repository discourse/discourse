import type { TOC } from "@ember/component/template-only";
import dIcon from "discourse/ui-kit/helpers/d-icon";

interface DInputTipSignature {
  Args: {
    /** The id of the tip, so that an input can point to it with `aria-describedby`. */
    id?: string;

    /** The validation result to show. Without a reason, the tip renders empty. */
    validation?: {
      /** Whether the validation failed. A failed tip shows a cross, any other a check. */
      failed?: boolean;

      /** The message explaining the result. */
      reason?: string | null;
    } | null;
  };

  Element: HTMLDivElement;
}

const DInputTip: TOC<DInputTipSignature> = <template>
  <div
    class="tip {{if @validation.failed 'bad' 'good'}}"
    id={{@id}}
    ...attributes
  >
    {{#if @validation.reason}}
      {{dIcon (if @validation.failed "xmark" "check")}}
      {{@validation.reason}}
    {{/if}}
  </div>
</template>;

export default DInputTip;
