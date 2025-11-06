import { computed } from "@ember/object";
import { and, reads } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { resolveComponent } from "select-kit/components/select-kit";
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

  <template>
    <div class="select-kit-header-wrapper">
      {{#each this.icons as |iconName|}} {{icon iconName}} {{/each}}

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

      {{#if this.shouldDisplayClearableButton}}
        <DButton
          @icon="xmark"
          @action={{this.selectKit.onClearSelection}}
          @ariaLabel="clear_input"
          class="btn-clear"
        />
      {{/if}}

      {{icon this.caretIcon class="caret-icon"}}
    </div>
  </template>
}
