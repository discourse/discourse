import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures";

/**
 * One variant, opened either empty or already holding a value, so the three can sit side by side
 * and their open behaviour be compared directly. Which option is active the moment the list
 * appears differs by variant, and that is far easier to see than to read out of the presenter.
 */
export default class OpenBehaviourSelectExample extends Component {
  @tracked value = this.args.initialValue ?? null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier={{@identifier}}
      @variant={{@variant}}
      @items={{LOCALES}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @label={{@label}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    />
  </template>
}
