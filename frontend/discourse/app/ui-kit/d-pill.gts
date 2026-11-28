import type { TOC } from "@ember/component/template-only";
import { concat } from "@ember/helper";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

interface DPillSignature {
  Args: {
    /** The text shown in the pill, already translated. */
    label: string;

    /**
     * What the pill conveys, which sets its colour. When omitted the pill is neutral, for plain
     * information such as a relative day.
     */
    type?: "neutral" | "info" | "success" | "warning" | "danger";

    /** The ID of an icon shown before the label, such as `circle` for a live state. */
    icon?: string;
  };
  Element: HTMLSpanElement;
}

/**
 * A short label on a tinted background, set beside other content: a relative day next to a time,
 * a "read-only" note on a category, how soon an event starts. Its colour comes from `@type`.
 *
 * The pill only shows text, so it is read as part of the content around it. Give it a `title`
 * when the label alone needs more context.
 */
const DPill: TOC<DPillSignature> = <template>
  <span
    class={{dConcatClass "d-pill" (if @type (concat "--" @type))}}
    ...attributes
  >
    {{~#if @icon~}}
      {{dIcon @icon}}
    {{~/if~}}
    {{~@label~}}
  </span>
</template>;

export default DPill;
