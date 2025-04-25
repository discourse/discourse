import { classNames } from "@ember-decorators/component";
import ComboBoxSelectBoxHeaderComponent from "select-kit/components/combo-box/combo-box-header";

@classNames("tag-drop-header")
export default class TagDropHeader extends ComboBoxSelectBoxHeaderComponent {}

<div class="select-kit-header-wrapper">
  {{component
    this.selectKit.options.selectedNameComponent
    tabindex=this.tabindex
    item=this.selectedContent
    selectKit=this.selectKit
    shouldDisplayClearableButton=this.shouldDisplayClearableButton
  }}

  {{d-icon this.caretIcon class="caret-icon"}}
</div>