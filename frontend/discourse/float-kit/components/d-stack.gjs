import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import { guidFor } from "@ember/object/internals";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";
import DSheet from "./d-sheet";

/**
 * Returns a stacking animation configuration based on track direction.
 * @param {"right" | "bottom"} tracks - The direction the stack tracks
 * @returns {{ translateX?: Function, translateY?: Function, scale: [number, number], transformOrigin: string }}
 */
function stackingAnimationFor(tracks) {
  return tracks === "right"
    ? {
        translateX: ({ progress }) =>
          progress <= 1
            ? progress * -10 + "px"
            : `calc(-12.5px + 2.5px * ${progress})`,
        scale: [1, 0.933],
        transformOrigin: "0 50%",
      }
    : {
        translateY: ({ progress }) =>
          progress <= 1
            ? progress * -10 + "px"
            : `calc(-12.5px + 2.5px * ${progress})`,
        scale: [1, 0.933],
        transformOrigin: "50% 0",
      };
}

/**
 * Shared template for rendering stack content with portal, view, backdrop, and content layers.
 * @component DStackSharedContent
 * @param {Object} sheet - The sheet controller instance
 * @param {"right" | "bottom"} tracks - The direction the stack tracks
 * @param {string} stackRoot - The stack root ID for nested stack association
 * @param {Object} stackingAnimation - Animation configuration for stacking behavior
 */
const DStackSharedContent = <template>
  <DSheet.Portal @sheet={{@sheet}}>
    <DSheet.View
      class="d-stack__view"
      @sheet={{@sheet}}
      @tracks={{@tracks}}
      @contentPlacement={{@tracks}}
    >
      <DSheet.Backdrop
        class="d-stack__backdrop"
        @sheet={{@sheet}}
        @travelAnimation={{hash opacity=(array 0 0.2)}}
      />
      <DSheet.Content
        class="d-stack__content"
        @sheet={{@sheet}}
        @stackingAnimation={{@stackingAnimation}}
      >
        <div class="d-stack__inner-content">
          {{yield
            (hash
              sheet=@sheet
              Trigger=(component DSheet.Trigger sheet=@sheet)
              Stack=(component DStackNested stackRoot=@stackRoot tracks=@tracks)
              dismiss=@sheet.close
            )
          }}
        </div>
      </DSheet.Content>
    </DSheet.View>
  </DSheet.Portal>
</template>;

/**
 * Content wrapper that computes stacking animation from the track direction.
 * @component DStackContent
 * @param {Object} sheet - The sheet controller instance
 * @param {string} stackRoot - The stack root ID for nested stack association
 * @param {"right" | "bottom"} tracks - The direction the stack tracks
 */
class DStackContent extends Component {
  /**
   * Computes the stacking animation config based on the track direction.
   * @returns {{ translateX?: Function, translateY?: Function, scale: [number, number], transformOrigin: string }}
   */
  get stackingAnimation() {
    return stackingAnimationFor(this.args.tracks);
  }

  <template>
    <DStackSharedContent
      @sheet={{@sheet}}
      @stackRoot={{@stackRoot}}
      @tracks={{@tracks}}
      @stackingAnimation={{this.stackingAnimation}}
      as |api|
    >
      {{yield api}}
    </DStackSharedContent>
  </template>
}

/**
 * Nested stack component that creates a new sheet root within an existing stack.
 * @component DStackNested
 * @param {string} stackRoot - The parent stack root ID
 * @param {"right" | "bottom"} tracks - The direction the stack tracks
 */
class DStackNested extends Component {
  /**
   * Auto-generated unique ID for this nested stack component.
   * @returns {string}
   */
  get componentId() {
    return guidFor(this);
  }

  /**
   * Computes the stacking animation config based on the track direction.
   * @returns {{ translateX?: Function, translateY?: Function, scale: [number, number], transformOrigin: string }}
   */
  get stackingAnimation() {
    return stackingAnimationFor(this.args.tracks);
  }

  <template>
    <DSheet.Root @forComponent={{@stackRoot}} as |sheet|>
      {{yield
        (hash
          Trigger=(component
            DSheet.Trigger forComponent=this.componentId sheet=sheet
          )
          Content=(component
            DStackSharedContent
            sheet=sheet
            stackRoot=@stackRoot
            tracks=@tracks
            stackingAnimation=this.stackingAnimation
          )
          present=sheet.open
          dismiss=sheet.close
        )
      }}
    </DSheet.Root>
  </template>
}

/**
 * Responsive stacking sheet component. Tracks right on large viewports, bottom on small.
 * @component DStack
 * @param {string} [componentId] - Optional explicit ID for the stack component
 * @param {boolean} [defaultPresented] - Whether the stack is initially presented (uncontrolled mode)
 * @param {boolean} [presented] - Controls the presented state (controlled mode)
 * @param {Function} [onPresentedChange] - Callback when presented state changes (controlled mode)
 * @param {Function} [onClosed] - Callback when the stack has fully closed
 */
export default class DStack extends Component {
  /**
   * Media query tracker for responsive direction switching.
   * @type {TrackedMediaQuery}
   */
  largeViewport = new TrackedMediaQuery("(min-width: 700px)");

  /**
   * Tears down the media query listener.
   */
  willDestroy() {
    super.willDestroy(...arguments);
    this.largeViewport.teardown();
  }

  /**
   * Determines the track direction based on viewport width.
   * @returns {"right" | "bottom"}
   */
  get tracks() {
    return this.largeViewport.matches ? "right" : "bottom";
  }

  /**
   * Resolved component ID, from args or auto-generated.
   * @returns {string}
   */
  get componentId() {
    return this.args.componentId ?? guidFor(this);
  }

  <template>
    <DSheet.Stack.Root as |stack|>
      <DSheet.Root
        @componentId={{this.componentId}}
        @forComponent={{stack.stackId}}
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
            Content=(component
              DStackContent
              sheet=sheet
              stackRoot=stack.stackId
              tracks=this.tracks
            )
            present=sheet.open
            dismiss=sheet.close
          )
        }}
      </DSheet.Root>
    </DSheet.Stack.Root>
  </template>
}
