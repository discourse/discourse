import type { TOC } from "@ember/component/template-only";
import { fn } from "@ember/helper";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import type { Row } from "discourse/ui-kit/d-reorderable-list/types";

interface RemovePartSignature {
  Args: {
    row: Row<unknown>;

    /** The icon to render, from the list's `@removeIcon`. */
    icon: string;

    /** The button weight, from the list's `removeButtonClass`. */
    buttonClass?: string;

    /** Reports the row the reader asked to remove. */
    onRemove: (key: string) => void;
  };
  Element: HTMLElement;
}

/**
 * The standard remove control for one row.
 *
 * Only its contract is fixed: an accessible name built from the row's own
 * label, so an icon-only control still says which row it removes. The visuals
 * are the consumer's, through `@icon` and `@buttonClass`. Reach for
 * `@buttonClass` rather than a `class` attribute: `class` merges with the one
 * set here rather than replacing it, so two competing button weights would
 * both land on the element.
 */
const RemovePart: TOC<RemovePartSignature> = <template>
  <DButton
    @icon={{@icon}}
    @action={{fn @onRemove @row.key}}
    @translatedAriaLabel={{@row.removeLabel}}
    @translatedTitle={{@row.removeLabel}}
    class="{{or @buttonClass 'btn-flat'}} d-reorderable-list__remove"
    ...attributes
  />
</template>;

export default RemovePart;
