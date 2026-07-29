import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { delay } from "../../../../../lib/select-fixtures";

export default class CustomEmptySelectExample extends Component {
  @tracked value = null;

  @action
  async load(_filter, { signal }) {
    await delay(signal, 400);
    return [];
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-custom-empty"
      @load={{this.load}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant="button"
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    >
      <:empty>
        {{i18n "styleguide.sections.select.content.empty_body"}}
      </:empty>
    </DSelect>
  </template>
}
