import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
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

  get actionLabel() {
    throw new Error("ButtonLabel is required for StartPostingOption");
  }

  @action
  onSelect() {
    throw new Error("onSelect is required for StartPostingOption");
  }

  <template>
    <div class={{concatClass "option" this.name}}>
      <h3>{{i18n this.title}}</h3>
      <p>
        {{i18n this.body}}
      </p>
      <DButton
        @label={{this.actionLabel}}
        @action={{this.onSelect}}
        class="btn-primary"
      />
    </div>
  </template>
}
