import Component from "@glimmer/component";
import DSheet from "./d-sheet";

export default class DSheetBottom extends Component {
  <template>
    <DSheet.Root @defaultPresented={{true}} as |sheet|>
      <DSheet.Portal @sheet={{sheet}}>
        <DSheet.View @sheet={{sheet}}>
          <DSheet.Backdrop @sheet={{sheet}} />
          <DSheet.Content
            class="BottomSheet-content ExampleBottomSheet-content"
            @sheet={{sheet}}
          >
            <DSheet.BleedingBackground
              @sheet={{sheet}}
              class="BottomSheet-bleedingBackground"
            />
            {{yield}}
          </DSheet.Content>
        </DSheet.View>
      </DSheet.Portal>
    </DSheet.Root>
  </template>
}
