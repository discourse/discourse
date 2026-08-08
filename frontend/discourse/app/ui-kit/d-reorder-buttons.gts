import Component from "@glimmer/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { modifier } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";

/**
 * Invoked when a direction is pressed. Variadic because the press event is
 * forwarded, and because a consumer normally binds its item with `fn`.
 */
type ReorderCallback = (...args: unknown[]) => void;

/** Which of the pair was pressed. */
type Direction = "up" | "down";

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
export default class DReorderButtons extends Component<DReorderButtonsSignature> {
  /**
   * Holds each button so focus can be taken back after a move.
   *
   * A ref rather than a query, because several of these render in one list and
   * the row this pair belongs to moves out from under any selector.
   */
  captureButton = modifier((element: HTMLElement, [direction]: [Direction]) => {
    this.#buttons.set(direction, element);
    return () => this.#buttons.delete(direction);
  });
  #buttons = new Map<Direction, HTMLElement>();

  @action
  moveDown(...args: unknown[]) {
    this.#move("down", this.args.disableDown, this.args.onMoveDown, args);
  }

  @action
  moveUp(...args: unknown[]) {
    this.#move("up", this.args.disableUp, this.args.onMoveUp, args);
  }

  /**
   * Runs a direction unless it is unavailable, then takes focus back.
   *
   * The disabled args are honoured here rather than by the `disabled` attribute
   * so the button stays focusable: it is announced as disabled, but a keyboard
   * user who reaches the end of the list keeps their place in the tab order
   * instead of being dropped to the top of the document.
   *
   * @param direction - Which button was pressed.
   * @param disabled - Whether that direction is unavailable.
   * @param callback - The consumer's handler for it.
   * @param args - Whatever the consumer bound with `fn`, plus the event.
   */
  #move(
    direction: Direction,
    disabled: boolean | undefined,
    callback: ReorderCallback | undefined,
    args: unknown[]
  ) {
    if (disabled) {
      return;
    }

    callback?.(...args);

    // Reordering moves this row within its list, and moving a focused element
    // in the DOM blurs it, so a keyboard user would otherwise land on the body
    // after one press and be unable to make a second.
    schedule("afterRender", () => this.#buttons.get(direction)?.focus());
  }

  <template>
    <span class="d-reorder-buttons" ...attributes>
      <DButton
        {{this.captureButton "up"}}
        @icon="chevron-up"
        @action={{this.moveUp}}
        @translatedAriaLabel={{@upLabel}}
        @translatedTitle={{@upLabel}}
        aria-disabled={{if @disableUp "true"}}
        class="btn-flat d-reorder-buttons__button"
      />
      <DButton
        {{this.captureButton "down"}}
        @icon="chevron-down"
        @action={{this.moveDown}}
        @translatedAriaLabel={{@downLabel}}
        @translatedTitle={{@downLabel}}
        aria-disabled={{if @disableDown "true"}}
        class="btn-flat d-reorder-buttons__button"
      />
    </span>
  </template>
}
