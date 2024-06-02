import Component from "@glimmer/component";
import icon from "discourse-common/helpers/d-icon";
import FkFormText from "./text";

export default class FormErrors extends Component {
  get withPrefix() {
    return this.args.withPrefix ?? false;
  }

  get visibleErrors() {
    console.log(this.args.names);
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
    <FkFormText
      class="d-form-errors"
      id={{@id}}
      aria-live="assertive"
      ...attributes
    >
      {{#each-in this.visibleErrors as |name errors|}}
        {{#each errors as |error|}}
          <span>
            {{icon "exclamation-triangle"}}
            {{error.message}}
          </span>
        {{/each}}
      {{/each-in}}
    </FkFormText>
  </template>
}
