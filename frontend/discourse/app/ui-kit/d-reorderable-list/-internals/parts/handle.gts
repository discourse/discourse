import Component from "@glimmer/component";
import { action } from "@ember/object";
import type { ModifierLike } from "@glint/template";
import DButton from "discourse/ui-kit/d-button";
import { HANDLE_ICON } from "discourse/ui-kit/d-reorderable-list/-internals/constants";
import type { Row } from "discourse/ui-kit/d-reorderable-list/types";
import { i18n } from "discourse-i18n";

interface HandlePartSignature {
  Args: {
    /** The row this handle moves. */
    row: Row<unknown>;

    /** Opens the list's shared menu against this row. */
    onOpen: (key: string) => void;

    /** Whether the shared menu is currently open on this row. */
    isOpen: boolean;

    /**
     * Records the handle's element against the row's key, so the list can
     * find the row's one control wherever it was placed.
     */
    register: ModifierLike<{
      Element: Element;
      Args: { Positional: [string] };
    }>;
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
      aria-describedby={{@row.descriptionId}}
      aria-haspopup={{if @row.hasDestinations "menu"}}
      class="btn-flat d-reorderable-list__handle"
      ...attributes
      @action={{this.open}}
      @ariaExpanded={{if @row.hasDestinations @isOpen}}
      @icon={{HANDLE_ICON}}
      @translatedAriaLabel={{@row.handleLabel}}
      @translatedTitle={{@row.handleLabel}}
      {{@register @row.key}}
    >
      <span class="sr-only" id={{@row.descriptionId}}>
        {{if
          @row.hasDestinations
          (i18n "reorder.handle_description")
          (i18n "reorder.handle_description_drag_only")
        }}
      </span>
    </DButton>
  </template>
}
