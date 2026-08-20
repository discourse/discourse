import type { TemplateOnlyComponent } from "@ember/component/template-only";
import dIcon from "discourse/ui-kit/helpers/d-icon";

interface DDragHandleSignature {
  Args: {
    /**
     * Translated name of what the handle drags, shown as its tooltip. Required
     * because a bare grip icon says nothing about which row it belongs to.
     */
    label: string;
  };
  Element: HTMLSpanElement;
}

/**
 * The grab affordance on a draggable row.
 *
 * Deliberately decorative: `aria-hidden` with no tab stop, because a drag is
 * unreachable by keyboard and exposing the handle would offer assistive
 * technology a control it cannot operate. The keyboard path is a separate pair
 * of buttons beside it, which is what `DReorderButtons` is for. Pair the two.
 *
 * This is NOT the right component for a handle that is itself an operable
 * control — one that takes focus and can be driven by keyboard. Use a real
 * button there and give it its own accessible name.
 *
 * Attributes pass through, so a consumer keeps its own class and can attach the
 * modifier that registers the handle with a drag source.
 *
 * @example
 * ```gjs
 * <DDragHandle @label={{this.dragLabel}} class="my-block__handle" />
 * ```
 */
const DDragHandle: TemplateOnlyComponent<DDragHandleSignature> = <template>
  <span
    class="d-drag-handle"
    aria-hidden="true"
    tabindex="-1"
    title={{@label}}
    ...attributes
  >{{dIcon "grip-vertical"}}</span>
</template>;

export default DDragHandle;
