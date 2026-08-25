import Component from "@glimmer/component";
import { action } from "@ember/object";
import type { ModifierLike } from "@glint/template";
import DButton from "discourse/ui-kit/d-button";
import type { Row } from "discourse/ui-kit/d-reorderable-list/types";
import { i18n } from "discourse-i18n";

interface HandlePartSignature {
  Args: {
    row: Row<unknown>;

    /** Opens the list's shared menu against this row. */
    onOpen: (key: string) => void;

    /** Whether the shared menu is currently open on this row. */
    isOpen: boolean;
    register: ModifierLike<{ Args: { Positional: [string] } }>;
  };
  Element: HTMLElement;
}

/**
 * The one control a movable row renders: a real button that is the drag
 * source and the move menu's trigger at once.
 *
 * Fusing the two is what lets the row carry a single affordance. A pointer
 * user drags it or clicks it for the menu; a keyboard user tabs or arrows onto
 * it and presses Enter for the same menu, because nothing intercepts a plain
 * button's native activation.
 *
 * The menu itself belongs to the list, not to this button: a list is arbitrarily
 * long, and one instance and one set of listeners per row is a cost that scales
 * with the wrong thing. The button therefore carries the menu's ARIA itself,
 * driven by the list's single record of which row is open.
 *
 * The drag registration belongs to the row for the same reason it is not here:
 * the registered element is what a drop target receives and what the browser
 * photographs for the drag preview. Registered on this button, a drag would
 * show a picture of the grip rather than of the row being moved. The row
 * registers instead and names this button as its `dragHandle`.
 */
export default class HandlePart extends Component<HandlePartSignature> {
  @action
  open() {
    this.args.onOpen(this.args.row.key);
  }

  <template>
    <DButton
      {{@register @row.key}}
      @icon="grip-vertical"
      @action={{this.open}}
      @translatedAriaLabel={{@row.handleLabel}}
      @translatedTitle={{@row.handleLabel}}
      @ariaExpanded={{@isOpen}}
      aria-describedby={{@row.descriptionId}}
      class="btn-flat d-reorderable-list__handle"
      ...attributes
    >
      <span id={{@row.descriptionId}} class="sr-only">
        {{i18n "reorder.handle_description"}}
      </span>
    </DButton>
  </template>
}
