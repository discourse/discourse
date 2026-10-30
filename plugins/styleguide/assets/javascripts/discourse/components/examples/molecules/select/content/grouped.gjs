import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES, scriptLabels } from "../../../../../lib/select-fixtures.js";

export default class GroupedSelectExample extends Component {
  @tracked value = null;

  @action
  groupHeader(key) {
    return scriptLabels()[key] ?? key;
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @groupBy="script"
      @groupHeader={{this.groupHeader}}
      @identifier="sg-grouped"
      @items={{LOCALES}}
      @onChange={{this.onChange}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.content.grouped_placeholder"
        )
      }}
      @value={{this.value}}
    >
      <:groupHeader as |group|>
        <span class="select-examples__group-header">
          {{dIcon "language"}}
          {{group.label}}
        </span>
      </:groupHeader>
    </DSelect>
  </template>
}
