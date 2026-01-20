import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { guidFor } from "@ember/object/internals";
import DSheet from "discourse/float-kit/components/d-sheet";

const BottomSheetContent = <template>
  <DSheet.Portal @sheet={{@sheet}}>
    <DSheet.View @sheet={{@sheet}}>
      <DSheet.Backdrop @sheet={{@sheet}} />
      <DSheet.Content class="bottom-sheet__content" @sheet={{@sheet}}>
        <DSheet.BleedingBackground
          @sheet={{@sheet}}
          class="bottom-sheet__bleeding-background"
        />
        <DSheet.Handle
          class="bottom-sheet__handle"
          @sheet={{@sheet}}
          @action="dismiss"
        />
        {{yield}}
      </DSheet.Content>
    </DSheet.View>
  </DSheet.Portal>
</template>;

export default class BottomSheet extends Component {
  get componentId() {
    return this.args.componentId ?? guidFor(this);
  }

  <template>
    <DSheet.Root
      class="bottom-sheet"
      @componentId={{this.componentId}}
      ...attributes
      as |sheet|
    >
      {{yield
        (hash
          Trigger=(component
            DSheet.Trigger
            forComponent=this.componentId
            sheet=sheet
          )
          Content=(component BottomSheetContent sheet=sheet)
          present=sheet.open
          dismiss=sheet.close
        )
      }}
    </DSheet.Root>
  </template>
}
