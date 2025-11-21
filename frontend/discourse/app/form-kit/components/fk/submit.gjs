import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class FKSubmit extends Component {
  get label() {
    if (this.args.label) {
      return this.args.label;
    }

    if (!this.args.icon) {
      return "submit";
    }
  }

  <template>
    <DButton
      @label={{this.label}}
      @icon={{@icon}}
      @action={{@onSubmit}}
      @forwardEvent="true"
      class="btn-primary form-kit__button"
      type="submit"
      @isLoading={{@isLoading}}
      @disabled={{@disabled}}
      ...attributes
    />
  </template>
}
