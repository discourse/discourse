import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import concatClass from "discourse/helpers/concat-class";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";
import DSheet from "./d-sheet";

export default class DSheetWithStacking extends Component {
  largeViewport = new TrackedMediaQuery("(min-width: 700px)");

  willDestroy() {
    super.willDestroy(...arguments);
    this.largeViewport.teardown();
  }

  get tracks() {
    return this.largeViewport.matches ? "right" : "bottom";
  }

  get componentId() {
    return this.args.componentId ?? guidFor(this);
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
        <DSheet.Trigger @sheet={{sheet}} @action="present">Test 2</DSheet.Trigger>

        {{yield
          (component
            DSheet.Trigger action="present" forComponent=this.componentId
          )
          to="root"
        }}
        <DSheet.Portal @sheet={{sheet}}>
          <DSheet.View
            class={{concatClass
              "SheetWithStacking-view"
              (concat "tracks-" this.tracks)
            }}
            @sheet={{sheet}}
            @tracks={{this.tracks}}
            @contentPlacement="center"
          >
            <DSheet.Backdrop
              class="SheetWithStacking-backdrop"
              @sheet={{sheet}}
              @travelAnimation={{hash opacity=(array 0 0.2)}}
              ...attributes
            />
            <DSheet.Content
              class={{concatClass
                "SheetWithStacking-content"
                (concat "tracks-" this.tracks)
              }}
              @sheet={{sheet}}
              @stackingAnimation={{this.stackingAnimation}}
            >
              <div class="SheetWithStacking-innerContent">
                {{yield sheet to="content"}}

                <DSheet.Root @forComponent={{stack.stackId}} as |nestedSheet|>
                  <DSheet.Trigger
                    @sheet={{nestedSheet}}
                    @action="present"
                  >Test</DSheet.Trigger>
                  <DSheet.Portal @sheet={{nestedSheet}}>
                    <DSheet.View
                      class={{concatClass
                        "SheetWithStacking-view"
                        (concat "tracks-" this.tracks)
                      }}
                      @sheet={{nestedSheet}}
                      @tracks={{this.tracks}}
                    >
                      <DSheet.Backdrop
                        class="SheetWithStacking-backdrop"
                        @sheet={{nestedSheet}}
                        @travelAnimation={{hash opacity=(array 0 0.2)}}
                        ...attributes
                      />
                      <DSheet.Content
                        class={{concatClass
                          "SheetWithStacking-content"
                          (concat "tracks-" this.tracks)
                        }}
                        @sheet={{nestedSheet}}
                        @stackingAnimation={{this.stackingAnimation}}
                      >
                        <div class="SheetWithStacking-innerContent">
                          {{yield nestedSheet to="nestedContent"}}
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
