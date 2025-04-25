<<<<<<< HEAD
<div class="select-kit-header-wrapper">
  {{#if this.icons}}
    <div class="future-date-input-selector-icons">
      {{#each this.icons as |icon|}} {{d-icon icon}} {{/each}}
    </div>
  {{/if}}

  {{component
    this.selectKit.options.selectedNameComponent
    tabindex=this.tabindex
    item=this.selectedContent
    selectKit=this.selectKit
  }}

  {{#if this.selectedContent.timeFormatted}}
    <span class="future-date-input-selector-datetime">
      {{this.selectedContent.timeFormatted}}
    </span>
  {{/if}}

  {{d-icon this.caretIcon class="caret-icon"}}
</div>
=======
import { classNames } from "@ember-decorators/component";
import ComboBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";

@classNames("future-date-input-selector-header")
export default class FutureDateInputSelectorHeader extends ComboBoxHeaderComponent {}
>>>>>>> a9ddbde3f6 (DEV: [gjs-codemod] renamed js to gjs)
