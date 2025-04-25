<<<<<<< HEAD
<div class="select-kit-header-wrapper">
  {{#each this.icons as |icon|}} {{d-icon icon}} {{/each}}

  {{component
    this.selectKit.options.selectedNameComponent
    tabindex=this.tabindex
    item=this.selectedContent
    selectKit=this.selectKit
  }}

  {{#if this.shouldDisplayClearableButton}}
    <DButton
      @icon="xmark"
      @action={{this.selectKit.onClearSelection}}
      @ariaLabel="clear_input"
      class="btn-clear"
    />
  {{/if}}

  {{d-icon this.caretIcon class="caret-icon"}}
</div>
=======
import { computed } from "@ember/object";
import { and, reads } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import SingleSelectHeaderComponent from "select-kit/components/select-kit/single-select-header";

@classNames("combo-box-header")
export default class ComboBoxHeader extends SingleSelectHeaderComponent {
  @reads("selectKit.options.clearable") clearable;
  @reads("selectKit.options.caretUpIcon") caretUpIcon;
  @reads("selectKit.options.caretDownIcon") caretDownIcon;
  @and("clearable", "value") shouldDisplayClearableButton;

  @computed("selectKit.isExpanded", "caretUpIcon", "caretDownIcon")
  get caretIcon() {
    return this.selectKit.isExpanded ? this.caretUpIcon : this.caretDownIcon;
  }
}
>>>>>>> a9ddbde3f6 (DEV: [gjs-codemod] renamed js to gjs)
