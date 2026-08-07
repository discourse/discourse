import type { TemplateOnlyComponent } from "@ember/component/template-only";
import DButton from "discourse/ui-kit/d-button";

/**
 * Invoked when a direction is pressed. Variadic because the press event is
 * forwarded, and because a consumer normally binds its item with `fn`.
 */
type ReorderCallback = (...args: unknown[]) => void;

interface DReorderButtonsSignature {
  Args: {
    /** Moves the item one place earlier in the list. */
    onMoveUp: ReorderCallback;

    /** Moves the item one place later in the list. */
    onMoveDown: ReorderCallback;

    /**
     * Whether moving earlier is unavailable, which is the case for the first
     * item in the list.
     */
    disableUp?: boolean;

    /**
     * Whether moving later is unavailable, which is the case for the last item
     * in the list.
     */
    disableDown?: boolean;

    /**
     * Translated name for the upward direction. Required because these are
     * icon-only buttons, so this is their only accessible name; it should name
     * the item too, so the buttons stay distinguishable when read out of
     * context.
     */
    upLabel: string;

    /** Translated name for the downward direction. See `upLabel`. */
    downLabel: string;
  };
  Element: HTMLSpanElement;
}

/**
 * The keyboard path for a reorderable list: a stacked pair of buttons that move
 * one item up or down.
 *
 * A drag is unreachable by keyboard, so any list whose only way to reorder is a
 * drag has no keyboard path at all. This is what a reorder surface pairs with
 * its drag handle to close that gap, and it exists as one component so the
 * surfaces do not each invent their own icons and sizing.
 *
 * Compact by design: it sits beside a drag handle in a dense list row and must
 * not drive the row's height. Layout within the row stays the consumer's, so
 * pass a class for anything positional such as `align-self`.
 *
 * @example
 * <DReorderButtons
 *   @onMoveUp={{fn this.moveUp item}}
 *   @onMoveDown={{fn this.moveDown item}}
 *   @disableUp={{item.isFirst}}
 *   @disableDown={{item.isLast}}
 *   @upLabel={{this.moveUpLabel}}
 *   @downLabel={{this.moveDownLabel}}
 *   class="my-block__arrows"
 * />
 *
 * Attributes pass through, so a consumer keeps its own class alongside this one.
 *
 * @see The `dDragAndDropSource` / `dDragAndDropTarget` pair for the drag half of
 *   the same surface.
 */
const DReorderButtons: TemplateOnlyComponent<DReorderButtonsSignature> =
  <template>
    <span class="d-reorder-buttons" ...attributes>
      <DButton
        @icon="chevron-up"
        @action={{@onMoveUp}}
        @disabled={{@disableUp}}
        @translatedAriaLabel={{@upLabel}}
        @translatedTitle={{@upLabel}}
        class="btn-flat d-reorder-buttons__button"
      />
      <DButton
        @icon="chevron-down"
        @action={{@onMoveDown}}
        @disabled={{@disableDown}}
        @translatedAriaLabel={{@downLabel}}
        @translatedTitle={{@downLabel}}
        class="btn-flat d-reorder-buttons__button"
      />
    </span>
  </template>;

export default DReorderButtons;
