import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
// import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DSheet from "discourse/float-kit/components/d-sheet";
import concatClass from "discourse/helpers/concat-class";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";

export default class AssignTopicSheet extends Component {
  @tracked reachedLastDetent = false;

  largeViewport = new TrackedMediaQuery("(min-width: 700px)");

  componentId = "test"; //guidFor(this);

  willDestroy() {
    super.willDestroy(...arguments);
    this.largeViewport.teardown();
  }

  get tracks() {
    return this.largeViewport.matches ? "right" : "bottom";
  }

  get detents() {
    return null;
    // return this.args.detents ?? ["66vh"];
  }

  @action
  setReachedLastDetent(value) {
    this.reachedLastDetent = value;
  }

  @action
  handleTravelStatusChange(status) {
    if (status === "idleOutside") {
      this.setReachedLastDetent(false);
    }
    this.onTravelStatusChange?.(status);
  }

  @action
  handleTravelRangeChange(range) {
    if (range.start === 2 && !this.args.reachedLastDetent) {
      this.setReachedLastDetent(true);
    }
    this.onTravelRangeChange?.(range);
  }

  @action
  handleTravel(event) {
    if (event.progress < 0.999 && this.view) {
      this.view.focus();
    }
    this.args.onTravel?.(event);
  }

  @action
  registerView(element) {
    this.view = element;
  }

  get stackingAnimation() {
    return this.tracks === "right"
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

  <template>
    <DSheet.Stack.Root as |stack|>

      <DSheet.Root
        @componentId={{this.componentId}}
        @forComponent={{stack.stackId}}
        as |sheet|
      >
        <DSheet.Trigger @forComponent={{this.componentId}} sheet={{sheet}}>
          OPEN
        </DSheet.Trigger>

        <DSheet.Portal @sheet={{sheet}}>
          <DSheet.View
            class="assign-sheet__view"
            @detents={{unless this.reachedLastDetent this.detents}}
            @swipeOvershoot={{false}}
            @onTravelStatusChange={{this.handleTravelStatusChange}}
            @onTravelRangeChange={{this.handleTravelRangeChange}}
            @onTravel={{this.handleTravel}}
            {{didInsert this.registerView}}
            @sheet={{sheet}}
            @setReachedLastDetent={{this.setReachedLastDetent}}
            @reachedLastDetent={{this.reachedLastDetent}}
            @tracks={{this.tracks}}
            ...attributes
          >
            <DSheet.Backdrop
              class="assign-sheet__backdrop"
              @themeColorDimming="auto"
              @sheet={{sheet}}
            />
            <DSheet.Content
              @stackingAnimation={{this.stackingAnimation}}
              class="assign-sheet__content"
              @sheet={{sheet}}
            >
              <div class="assign-sheet__inner-content">
                <DSheet.Handle
                  class="SheetWithDetent-handle"
                  @sheet={{sheet}}
                  @action={{if this.reachedLastDetent "dismiss" "step"}}
                />

                <DSheet.Root @forComponent={{stack.stackId}} as |nestedSheet|>
                  <DSheet.Trigger
                    @sheet={{nestedSheet}}
                    @action="present"
                  >Test</DSheet.Trigger>
                  <DSheet.Portal @sheet={{nestedSheet}}>
                    <DSheet.View
                      class="assign-sheet__view"
                      @sheet={{nestedSheet}}
                      @tracks={{this.tracks}}
                    >
                      <DSheet.Backdrop
                        class="assign-sheet__backdrop"
                        @sheet={{nestedSheet}}
                        ...attributes
                      />
                      <DSheet.Content
                        @sheet={{nestedSheet}}
                        @stackingAnimation={{this.stackingAnimation}}
                        class="assign-sheet__content"
                      >
                        <div class="assign-sheet__inner-content">
                          NESTED
                        </div>
                      </DSheet.Content>
                    </DSheet.View>
                  </DSheet.Portal>
                </DSheet.Root>
              </div>
            </DSheet.Content>
          </DSheet.View>
        </DSheet.Portal>
      </DSheet.Root>
    </DSheet.Stack.Root>
  </template>
}
