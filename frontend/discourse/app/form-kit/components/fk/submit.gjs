import Component from "@glimmer/component";
import DButton from "discourse/ui-kit/d-button";

export default class FKSubmit extends Component {
  get label() {
    return this.args.label ?? "submit";
  }

  <template>
    <DButton
      class="btn-primary form-kit__button"
      type="submit"
      ...attributes
      @action={{@onSubmit}}
      @disabled={{@disabled}}
      @forwardEvent="true"
      @isLoading={{@isLoading}}
      @label={{this.label}}
    />
  </template>
}
