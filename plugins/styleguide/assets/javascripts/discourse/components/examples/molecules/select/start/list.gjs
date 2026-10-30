import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { i18n } from "discourse-i18n";

export default class ListSelectStartExample extends Component {
  @tracked value = ["email"];

  items = [
    { id: "email", name: "Email" },
    { id: "push", name: "Push notifications" },
    { id: "chat", name: "Chat messages" },
    { id: "digest", name: "Weekly digest" },
  ];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelectList
      @ariaLabel={{i18n "styleguide.sections.select.list_start_label"}}
      @identifier="sg-list-start"
      @items={{this.items}}
      @onChange={{this.onChange}}
      @value={{this.value}}
    />
  </template>
}
