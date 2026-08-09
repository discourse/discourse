import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { guidFor } from "@ember/object/internals";
import DSheet from "./d-sheet";

const ENTERING_ANIMATION_SETTINGS = Object.freeze({
  easing: "spring",
  stiffness: 260,
  damping: 20,
  mass: 1,
});
const BACKDROP_TRAVEL_ANIMATION = Object.freeze({
  opacity: ({ progress }) => Math.min(0.4 * progress, 0.4),
});
const CONTENT_TRAVEL_ANIMATION = Object.freeze({
  scale: Object.freeze([0.8, 1]),
});
const DCardContent = <template>
  <DSheet.Portal @sheet={{@sheet}}>
    <DSheet.View
      class="d-card"
      @sheet={{@sheet}}
      @contentPlacement="center"
      @tracks="top"
      @bottomColorHint={{false}}
      @enteringAnimationSettings={{ENTERING_ANIMATION_SETTINGS}}
    >
      <DSheet.Backdrop
        @travelAnimation={{BACKDROP_TRAVEL_ANIMATION}}
        @themeColorDimming="auto"
        @sheet={{@sheet}}
      />
      <DSheet.Content
        @travelAnimation={{CONTENT_TRAVEL_ANIMATION}}
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
</template>;

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
