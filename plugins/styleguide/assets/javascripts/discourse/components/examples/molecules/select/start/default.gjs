import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

export default class DefaultSelectExample extends Component {
  @tracked value = null;

  items = [
    { id: "draft", name: "Draft" },
    { id: "published", name: "Published" },
    { id: "archived", name: "Archived" },
    { id: "scheduled", name: "Scheduled" },
  ];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-default"
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    />
  </template>
}
