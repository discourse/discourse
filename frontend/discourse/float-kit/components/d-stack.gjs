import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import { guidFor } from "@ember/object/internals";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";
import DSheet from "./d-sheet";

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

class DStackContent extends Component {
  get stackingAnimation() {
    return stackingAnimationFor(this.args.tracks);
  }

  <template>
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
          @stackingAnimation={{this.stackingAnimation}}
        >
          <div class="d-stack__inner-content">
            {{yield
              (hash
                sheet=@sheet
                Trigger=(component DSheet.Trigger sheet=@sheet)
                Stack=(component
                  DStackNested stackRoot=@stackRoot tracks=@tracks
                )
                dismiss=@sheet.close
              )
            }}
          </div>
        </DSheet.Content>
      </DSheet.View>
    </DSheet.Portal>
  </template>
}

class DStackNested extends Component {
  get componentId() {
    return guidFor(this);
  }

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
            DStackNestedContent
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

const DStackNestedContent = <template>
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

export default class DStack extends Component {
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

  <template>
    <DSheet.Stack.Root as |stack|>
      <DSheet.Root
        @componentId={{this.componentId}}
        @forComponent={{stack.stackId}}
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
