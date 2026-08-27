import type { TOC } from "@ember/component/template-only";
import { fn } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import type { Row } from "discourse/ui-kit/d-reorderable-list/types";

interface RemovePartSignature {
  Args: {
    row: Row<unknown>;

    /** The icon to render, from the list's `@removeIcon`. */
    icon: string;

    /** Reports the row the reader asked to remove. */
    onRemove: (key: string) => void;
  };
  Element: HTMLElement;
}

/**
 * The standard remove control for one row.
 *
 * Only its contract is fixed: an accessible name built from the row's own
 * label, and the disabled state the list computed. Everything visual is the
 * consumer's — `@icon` and any attribute pass straight through — because a
 * settings row and an admin table want different weights for the same action.
 *
 * The name is the part worth centralising. Every surface that hand-rolled this
 * rendered an icon-only button with no name at all, so a ten-row list offered a
 * reader ten identical "button"s and no way to tell what each one removed.
 */
const RemovePart: TOC<RemovePartSignature> = <template>
  <DButton
    @icon={{@icon}}
    @action={{fn @onRemove @row.key}}
    @translatedAriaLabel={{@row.removeLabel}}
    @translatedTitle={{@row.removeLabel}}
    class="btn-flat d-reorderable-list__remove"
    ...attributes
  />
</template>;

export default RemovePart;
