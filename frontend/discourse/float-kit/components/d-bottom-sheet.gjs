import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DSheet from "discourse/float-kit/components/d-sheet";
import concatClass from "discourse/helpers/concat-class";

/** @type {string[]} Default detent stops for the bottom sheet view. */
const DETENTS = ["66vh"];

/**
 * Scrollable area within a bottom sheet that adapts scroll behavior based on detent state.
 *
 * @component BottomSheetScrollArea
 * @param {boolean} reachedLastDetent - Whether the sheet has expanded to its last detent position.
 */
const BottomSheetScrollArea = <template>
  <DSheet.Scroll.Root as |controller|>
    <DSheet.Scroll.View
      class="bottom-sheet__scroll-view"
      @scrollGesture={{if @reachedLastDetent "auto" false}}
      @scrollGestureTrap={{hash yEnd=true}}
      @safeArea="layout-viewport"
      @onScrollStart={{hash dismissKeyboard=true}}
      @controller={{controller}}
    >
      <DSheet.Scroll.Content
        class="bottom-sheet__scroll-content"
        @controller={{controller}}
      >
        {{yield}}
      </DSheet.Scroll.Content>
    </DSheet.Scroll.View>
  </DSheet.Scroll.Root>
</template>;

/**
 * View wrapper that manages expandable detent behavior and travel state for the bottom sheet.
 *
 * @component ExpandableView
 * @param {Object} sheet - The DSheet instance controlling the sheet.
 * @param {boolean} reachedLastDetent - Whether the sheet has expanded to its last detent position.
 * @param {(value: boolean) => void} setReachedLastDetent - Callback to update the last detent state.
 */
class ExpandableView extends Component {
  /** @type {HTMLElement | undefined} Reference to the view DOM element. */
  view;

  /**
   * Resets the last detent state when travel moves outside the sheet.
   *
   * @param {string} status - The travel status identifier.
   */
  @action
  handleTravelStatusChange(status) {
    if (status === "idleOutside") {
      this.args.setReachedLastDetent(false);
    }
  }

  /**
   * Sets the last detent state when travel range reaches the final detent.
   *
   * @param {{ start: number }} range - The travel range with start position index.
   */
  @action
  handleTravelRangeChange(range) {
    if (range.start === 2 && !this.args.reachedLastDetent) {
      this.args.setReachedLastDetent(true);
    }
  }

  /**
   * Focuses the view element when travel progress is below threshold and focus is outside.
   *
   * @param {{ progress: number }} event - The travel event with progress value.
   */
  @action
  handleTravel(event) {
    if (event.progress < 0.999 && this.view) {
      if (!this.view.contains(document.activeElement)) {
        this.view.focus();
      }
    }
  }

  /**
   * Stores a reference to the view DOM element on insert.
   *
   * @param {HTMLElement} element - The view DOM element.
   */
  @action
  registerView(element) {
    this.view = element;
  }

  <template>
    <DSheet.View
      class="bottom-sheet__view"
      @sheet={{@sheet}}
      @detents={{unless @reachedLastDetent DETENTS}}
      @swipeOvershoot={{false}}
      @onTravelStatusChange={{this.handleTravelStatusChange}}
      @onTravelRangeChange={{this.handleTravelRangeChange}}
      @onTravel={{this.handleTravel}}
      {{didInsert this.registerView}}
    >
      {{yield}}
    </DSheet.View>
  </template>
}

/**
 * Inner content layout for the bottom sheet including backdrop, handle, and bleeding background.
 *
 * @component BottomSheetInnerContent
 * @param {Object} sheet - The DSheet instance controlling the sheet.
 * @param {boolean} expandable - Whether the sheet supports expanding to additional detents.
 * @param {string} handleAction - The handle action type ("dismiss" or "step").
 */
const BottomSheetInnerContent = <template>
  <DSheet.Backdrop @sheet={{@sheet}} />
  <DSheet.Content
    class={{concatClass
      "bottom-sheet__content"
      (if @expandable "--expandable")
    }}
    @sheet={{@sheet}}
  >
    <DSheet.BleedingBackground
      @sheet={{@sheet}}
      class="bottom-sheet__bleeding-background"
    />
    <DSheet.Handle
      class="bottom-sheet__handle"
      @sheet={{@sheet}}
      @action={{@handleAction}}
    />
    {{yield}}
  </DSheet.Content>
</template>;

/**
 * Content wrapper that renders either an expandable or fixed bottom sheet layout.
 *
 * @component BottomSheetContent
 * @param {Object} sheet - The DSheet instance controlling the sheet.
 * @param {boolean} expandable - Whether the sheet supports expanding to additional detents.
 * @param {boolean} reachedLastDetent - Whether the sheet has expanded to its last detent position.
 * @param {(value: boolean) => void} setReachedLastDetent - Callback to update the last detent state.
 */
const BottomSheetContent = <template>
  <DSheet.Portal @sheet={{@sheet}}>
    {{#if @expandable}}
      <ExpandableView
        @sheet={{@sheet}}
        @reachedLastDetent={{@reachedLastDetent}}
        @setReachedLastDetent={{@setReachedLastDetent}}
      >
        <BottomSheetInnerContent
          @sheet={{@sheet}}
          @expandable={{true}}
          @handleAction={{if @reachedLastDetent "dismiss" "step"}}
        >
          {{yield
            (hash
              ScrollArea=(component
                BottomSheetScrollArea reachedLastDetent=@reachedLastDetent
              )
              Trigger=(component DSheet.Trigger sheet=@sheet)
              expand=(fn @sheet.stepToDetent 2)
              isExpanded=@reachedLastDetent
              dismiss=@sheet.close
            )
          }}
        </BottomSheetInnerContent>
      </ExpandableView>
    {{else}}
      <DSheet.View class="bottom-sheet__view" @sheet={{@sheet}}>
        <BottomSheetInnerContent
          @sheet={{@sheet}}
          @expandable={{false}}
          @handleAction="dismiss"
        >
          {{yield
            (hash
              ScrollArea=(component
                BottomSheetScrollArea reachedLastDetent=false
              )
              Trigger=(component DSheet.Trigger sheet=@sheet)
              dismiss=@sheet.close
            )
          }}
        </BottomSheetInnerContent>
      </DSheet.View>
    {{/if}}
  </DSheet.Portal>
</template>;

/**
 * A mobile-friendly bottom sheet component that slides up from the bottom of the screen.
 *
 * @component DBottomSheet
 * @param {string} [componentId] - Optional unique identifier for the sheet instance.
 * @param {boolean} [defaultPresented] - Whether the sheet is presented by default.
 * @param {boolean} [presented] - Controlled presentation state.
 * @param {(presented: boolean) => void} [onPresentedChange] - Callback when presentation state changes.
 * @param {() => void} [onClosed] - Callback when the sheet is closed.
 * @param {boolean} [expandable] - Whether the sheet supports expanding to additional detents.
 */
export default class DBottomSheet extends Component {
  /** @type {boolean} Whether the sheet has expanded to its last detent position. */
  @tracked reachedLastDetent = false;

  /**
   * Unique identifier for the sheet, falling back to a generated GUID.
   *
   * @returns {string}
   */
  get componentId() {
    return this.args.componentId ?? guidFor(this);
  }

  /**
   * Updates the tracked state for whether the last detent has been reached.
   *
   * @param {boolean} value - The new reached last detent state.
   */
  @action
  setReachedLastDetent(value) {
    this.reachedLastDetent = value;
  }

  <template>
    <DSheet.Root
      class="bottom-sheet"
      @componentId={{this.componentId}}
      @defaultPresented={{@defaultPresented}}
      @presented={{@presented}}
      @onPresentedChange={{@onPresentedChange}}
      @onClosed={{@onClosed}}
      ...attributes
      as |sheet|
    >
      {{yield
        (hash
          Trigger=(component
            DSheet.Trigger forComponent=this.componentId sheet=sheet
          )
          Content=(component
            BottomSheetContent
            sheet=sheet
            expandable=@expandable
            reachedLastDetent=this.reachedLastDetent
            setReachedLastDetent=this.setReachedLastDetent
          )
          present=sheet.open
          dismiss=sheet.close
        )
      }}
    </DSheet.Root>
  </template>
}
