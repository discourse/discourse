// @ts-check
import dIcon from "discourse/ui-kit/helpers/d-icon";

/**
 * Editor-aware implementation of the icon inner-content component
 * yielded as `R.Content` by `IconRenderer`. Swapped in over the
 * minimal default by the wireframe service's `enter()` (and reverted
 * by `exit()`) so the scaffold is only present while the editor is
 * actively open.
 *
 * Renders the same DOM as the minimal renderer (nothing when empty,
 * the icon glyph otherwise) wrapped in a `.wf-inline-icon` span that
 * carries the `data-wf-inline-edit-*` attrs the block-chrome's
 * onClick reads to open the icon picker popover. We deliberately do
 * NOT render a placeholder on empty values: a stray glyph in the
 * rendered text flow disrupts the heading's layout and reads as a
 * real icon to authors. Authors set the initial icon via the
 * inspector; subsequent edits go through this inline path.
 */
const ScaffoldedIconRenderer = <template>
  {{#if @value}}
    <span
      class="wf-inline-icon"
      data-wf-inline-edit-arg={{@arg}}
      data-wf-inline-edit-kind="icon"
      ...attributes
    >
      {{dIcon @value}}
    </span>
  {{/if}}
</template>;

export default ScaffoldedIconRenderer;
