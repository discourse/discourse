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
 * source and the move menu's trigger at once, so a pointer drags or clicks it
 * and a keyboard activates it, with nothing intercepting a plain button.
 *
 * The menu itself belongs to the list, not to this button; the button carries
 * only the menu's ARIA, driven by the list's single record of which row is
 * open.
 *
 * The drag registration belongs to the row: the registered element is what
 * the browser photographs for the drag preview, and registered here a drag
 * would show the grip rather than the row. The row registers instead and
 * names this button as its `dragHandle`.
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
      @ariaExpanded={{if @row.hasDestinations @isOpen}}
      aria-haspopup={{if @row.hasDestinations "menu"}}
      aria-describedby={{@row.descriptionId}}
      class="btn-flat d-reorderable-list__handle"
      ...attributes
    >
      <span id={{@row.descriptionId}} class="sr-only">
        {{if
          @row.hasDestinations
          (i18n "reorder.handle_description")
          (i18n "reorder.handle_description_drag_only")
        }}
      </span>
    </DButton>
  </template>
}
