import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class StartPostingOption extends Component {
  get name() {
    throw new Error("Name is required for StartPostingOption");
  }

  get title() {
    throw new Error("Title is required for StartPostingOption");
  }

  get body() {
    throw new Error("Body is required for StartPostingOption");
  }

  @action
  onSelect() {
    throw new Error("onSelect is required for StartPostingOption");
  }

  <template>
    <button
      type="button"
      class={{concatClass "start-posting-options-modal__card" this.name}}
      disabled={{this.disableAction}}
      {{on "click" this.onSelect}}
    >
      <span class="start-posting-options-modal__title">
        {{i18n this.title}}
      </span>
      <p class="start-posting-options-modal__body">
        {{i18n this.body}}
      </p>
    </button>
  </template>
}
