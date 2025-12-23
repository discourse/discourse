import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import ComboBoxSelectBoxHeaderComponent from "discourse/select-kit/components/combo-box/combo-box-header";
import { resolveComponent } from "discourse/select-kit/components/select-kit";

@classNames("category-drop-header")
export default class CategoryDropHeader extends ComboBoxSelectBoxHeaderComponent {
  @computed("selectedContent.color")
  get categoryBackgroundColor() {
    return this.selectedContent?.color || "#e9e9e9";
  }

  @computed("selectedContent.text_color")
  get categoryTextColor() {
    return this.selectedContent?.text_color || "#333";
  }

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
