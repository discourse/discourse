import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class FKSubmit extends Component {
  get label() {
    return this.args.label ?? "submit";
  }

  <template>
    <DButton
      @label={{this.label}}
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
