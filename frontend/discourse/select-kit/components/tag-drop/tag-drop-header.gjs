import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import ComboBoxSelectBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";
import { resolveComponent } from "select-kit/components/select-kit";

@classNames("tag-drop-header")
export default class TagDropHeader extends ComboBoxSelectBoxHeaderComponent {
  <template>
    <div class="select-kit-header-wrapper">
      {{#let
        (resolveComponent this this.selectKit.options.selectedNameComponent)
        as |SelectedNameComponent|
      }}
        <SelectedNameComponent
          @tabindex={{this.tabindex}}
          @item={{this.selectedContent}}
          @selectKit={{this.selectKit}}
          @shouldDisplayClearableButton={{this.shouldDisplayClearableButton}}
        />
      {{/let}}

      {{icon this.caretIcon class="caret-icon"}}
    </div>
  </template>
}
