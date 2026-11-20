import type { TOC } from "@ember/component/template-only";
import { HANDLE_ICON } from "discourse/ui-kit/d-reorderable-list/-internals/constants";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/**
 * Holds a handle's place in a row that renders none, so the row's content
 * starts where its neighbours' does. It carries the handle's own icon,
 * invisible, so the two stay the same width at any font size. Hidden from
 * assistive technology: it is spacing, not a control.
 */
const HandleSlotPart: TOC<{ Element: HTMLSpanElement }> = <template>
  <span
    aria-hidden="true"
    class="d-reorderable-list__handle-slot"
    ...attributes
  >{{dIcon HANDLE_ICON}}</span>
</template>;

export default HandleSlotPart;
