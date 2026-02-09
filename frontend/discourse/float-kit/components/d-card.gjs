import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import DSheet from "./d-sheet";

/**
 * Internal content component for DCard, renders the portal, view, backdrop, and content.
 *
 * @component DCardContent
 * @param {Object} sheet - The sheet controller instance
 */
class DCardContent extends Component {
  /**
   * Computes backdrop opacity from travel progress, capped at 0.4.
   *
   * @param {number} progress - Travel progress value between 0 and 1
   * @returns {number} Opacity value capped at 0.4
   */
  @action
  backdropTravelAnimation(progress) {
    return Math.min(0.4 * progress, 0.4);
  }

  <template>
    <DSheet.Portal @sheet={{@sheet}}>
      <DSheet.View
        class="d-card"
        @sheet={{@sheet}}
        @contentPlacement="center"
        @tracks="top"
        @bottomColorHint={{false}}
        @enteringAnimationSettings={{hash
          easing="spring"
          stiffness=260
          damping=20
          mass=1
        }}
      >
        <DSheet.Backdrop
          @travelAnimation={{this.backdropTravelAnimation}}
          @themeColorDimming="auto"
          @sheet={{@sheet}}
        />
        <DSheet.Content
          @travelAnimation={{hash scale=(array 0.8 1)}}
          @sheet={{@sheet}}
          as |ContentTag|
        >
          <ContentTag class="d-card-content">
            {{yield
              (hash
                Trigger=(component DSheet.Trigger sheet=@sheet)
                dismiss=@sheet.close
              )
            }}
          </ContentTag>
        </DSheet.Content>
      </DSheet.View>
    </DSheet.Portal>
  </template>
}

/**
 * Card component that wraps a sheet with centered content and a scaling entrance animation.
 *
 * @component DCard
 * @param {string} [componentId] - Optional ID for forComponent lookups, defaults to guidFor(this)
 * @param {boolean} [defaultPresented] - Whether the card is initially presented (uncontrolled mode)
 * @param {boolean} [presented] - Controls the presented state (controlled mode)
 * @param {Function} [onPresentedChange] - Callback when presented state changes (controlled mode)
 * @param {Function} [onClosed] - Callback when the card has fully closed
 */
export default class DCard extends Component {
  /**
   * Resolved component ID, falling back to a generated GUID.
   *
   * @returns {string} The component ID
   */
  get componentId() {
    return this.args.componentId ?? guidFor(this);
  }

  <template>
    <DSheet.Root
      @componentId={{this.componentId}}
      @defaultPresented={{@defaultPresented}}
      @presented={{@presented}}
      @onPresentedChange={{@onPresentedChange}}
      @onClosed={{@onClosed}}
      as |sheet|
    >
      {{yield
        (hash
          Trigger=(component
            DSheet.Trigger forComponent=this.componentId sheet=sheet
          )
          Content=(component DCardContent sheet=sheet)
          present=sheet.open
          dismiss=sheet.close
        )
      }}
    </DSheet.Root>
  </template>
}
