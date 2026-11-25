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

    /** Registers the grip with its owning list. */
    register: ModifierLike<{ Element: HTMLElement }>;
  };
  Element: HTMLElement;
}

/**
 * Tapping or activating the grip opens the list's move menu. The row owns
 * the native drag registration so the browser previews the entire row.
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
      data-reorderable-handle-key={{@row.key}}
      data-swipe-ignore
      ...attributes
      @action={{this.open}}
      @ariaExpanded={{if @row.hasDestinations @isOpen}}
      @icon={{HANDLE_ICON}}
      @translatedAriaLabel={{@row.handleLabel}}
      @translatedTitle={{@row.handleLabel}}
      {{@register}}
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
