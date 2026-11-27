import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/**
 * A toolbar popup menu whose options are values, such as the post's language, drawn as a select
 * that sits in the toolbar's arrow-key order.
 */
export default class ToolbarPopupSelect extends Component {
  get options() {
    return this.args.content
      .filter((option) => option.condition !== false)
      .map((option) =>
        selectOption(option, {
          label: option.translatedLabel ?? i18n(option.label),
        })
      );
  }

  get textManipulationState() {
    return this.args.context?.textManipulation?.state;
  }

  get icon() {
    const icon = this.args.icon;
    return typeof icon === "function"
      ? icon({ state: this.textManipulationState })
      : icon;
  }

  get triggerLabel() {
    const label = this.args.triggerLabel;
    return typeof label === "function"
      ? label({ state: this.textManipulationState })
      : label;
  }

  @action
  change(name) {
    this.args.onChange?.(
      this.args.content.find((option) => option.name === name)
    );
  }

  @action
  handleKeydown(event) {
    this.args.onKeydown?.(event);
  }

  <template>
    <DSelect
      class={{dConcatClass "toolbar__button toolbar-popup-select" @class}}
      tabindex={{@tabindex}}
      title={{@title}}
      @clearMode="never"
      @icon={{this.icon}}
      @identifier={{@identifier}}
      @onChange={{this.change}}
      @onShow={{@onOpen}}
      @options={{this.options}}
      @selectedIcon="check"
      @showCaret={{false}}
      @texts={{hash ariaLabel=@title}}
      @value={{@value}}
      @valueField="name"
      @variant="static"
      {{on "keydown" this.handleKeydown}}
    >
      <:listHeader>
        {{#if @header}}
          <div class="toolbar-popup-select__header">
            {{~@header~}}
          </div>
        {{/if}}
      </:listHeader>
      <:selection as |option|>
        {{#if this.triggerLabel}}
          <span aria-hidden="true" class="toolbar-popup-select__trigger-label">
            {{~this.triggerLabel~}}
          </span>
        {{/if}}
        <span class="sr-only">{{option.label}}</span>
      </:selection>
    </DSelect>
  </template>
}
