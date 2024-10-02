import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class FKSubmit extends Component {
  get label() {
    return this.args.label ?? "submit";
  }

  get icon() {
    return this.args.icon ?? null;
  }

  <template>
    <DButton
      @label={{this.label}}
      @icon={{this.icon}}
      @action={{@onSubmit}}
      @forwardEvent="true"
      class="btn-primary form-kit__button"
      type="submit"
      @isLoading={{@isLoading}}
      ...attributes
    />
  </template>
}
