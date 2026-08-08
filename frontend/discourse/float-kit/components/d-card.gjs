import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import DSheet from "./d-sheet";

class DCardContent extends Component {
  @action
  backdropTravelAnimation({ progress }) {
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
          @travelAnimation={{hash opacity=this.backdropTravelAnimation}}
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
                dismiss=@sheet.requestDismiss
              )
            }}
          </ContentTag>
        </DSheet.Content>
      </DSheet.View>
    </DSheet.Portal>
  </template>
}

export default class DCard extends Component {
  get componentId() {
    return this.args.componentId ?? guidFor(this);
  }

  <template>
    <DSheet.Root
      @componentId={{this.componentId}}
      @sheetRole="dialog"
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
          Content=(component DCardContent sheet=sheet)
          present=sheet.requestPresent
          dismiss=sheet.requestDismiss
        )
      }}
    </DSheet.Root>
  </template>
}
