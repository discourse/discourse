import { tracked } from "@glimmer/tracking";
import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { resolveComponent } from "discourse/select-kit/components/select-kit";
import SingleSelectHeaderComponent from "discourse/select-kit/components/select-kit/single-select-header";

@classNames("combo-box-header")
export default class ComboBoxHeader extends SingleSelectHeaderComponent {
  @tracked _clearableOverride;
  @tracked _caretUpIconOverride;
  @tracked _caretDownIconOverride;

  @computed("selectKit.options.clearable")
  get clearable() {
    if (this._clearableOverride !== undefined) {
      return this._clearableOverride;
    }
    return this.selectKit?.options?.clearable;
  }

  set clearable(value) {
    this._clearableOverride = value;
  }

  @computed("selectKit.options.caretUpIcon")
  get caretUpIcon() {
    if (this._caretUpIconOverride !== undefined) {
      return this._caretUpIconOverride;
    }
    return this.selectKit?.options?.caretUpIcon;
  }

  set caretUpIcon(value) {
    this._caretUpIconOverride = value;
  }

  @computed("selectKit.options.caretDownIcon")
  get caretDownIcon() {
    if (this._caretDownIconOverride !== undefined) {
      return this._caretDownIconOverride;
    }
    return this.selectKit?.options?.caretDownIcon;
  }

  set caretDownIcon(value) {
    this._caretDownIconOverride = value;
  }

  @computed("clearable", "value")
  get shouldDisplayClearableButton() {
    return this.clearable && this.value;
  }

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
          class="btn-clear btn-transparent"
        />
      {{/if}}

      {{#if this.caretIcon}}
        {{icon this.caretIcon class="angle-icon"}}
      {{/if}}
    </div>
  </template>
}
