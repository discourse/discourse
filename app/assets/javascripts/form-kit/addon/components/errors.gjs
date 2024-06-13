import Component from "@glimmer/component";
import icon from "discourse-common/helpers/d-icon";

export default class FKErrors extends Component {
  get visibleErrors() {
    if (!this.args.names) {
      return this.args.errors;
    }

    const names = this.args.names.split(",");

    const visibleErrors = {};
    for (const [field, errors] of Object.entries(this.args.errors)) {
      if (names.includes(field)) {
        visibleErrors[field] = errors;
      }
    }

    return visibleErrors;
  }

  <template>
    <p class="d-form__errors" id={{@id}} aria-live="assertive" ...attributes>
      {{#each-in this.visibleErrors as |name errors|}}
        {{#each errors as |error|}}
          <span>
            {{icon "exclamation-triangle"}}
            {{error.message}}
          </span>
        {{/each}}
      {{/each-in}}
    </p>
  </template>
}
