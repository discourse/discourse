import { classNames } from "@ember-decorators/component";
import ComboBoxHeaderComponent from "discourse/select-kit/components/combo-box/combo-box-header";
import { resolveComponent } from "discourse/select-kit/components/select-kit";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@classNames("future-date-input-selector-header")
export default class FutureDateInputSelectorHeader extends ComboBoxHeaderComponent {
  <template>
    <div class="select-kit-header-wrapper">
      {{#if this.icons}}
        <div class="future-date-input-selector-icons">
          {{#each this.icons as |iconName|}} {{dIcon iconName}} {{/each}}
        </div>
      {{/if}}

      {{#let
        (resolveComponent this this.selectKit.options.selectedNameComponent)
        as |SelectedNameComponent|
      }}
        <SelectedNameComponent
          @tabindex={{this.tabindex}}
          @item={{this.selectedContent}}
          @selectKit={{this.selectKit}}
        />
      {{/let}}

      {{#if this.selectedContent.timeFormatted}}
        <span class="future-date-input-selector-datetime">
          {{this.selectedContent.timeFormatted}}
        </span>
      {{/if}}

      {{dIcon this.caretIcon class="angle-icon"}}
    </div>
  </template>
}
