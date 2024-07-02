import Component from "@glimmer/component";
import icon from "discourse-common/helpers/d-icon";
import { makeArray } from "discourse-common/lib/helpers";

export default class FKErrors extends Component {
  get withTitle() {
    return this.args.withTitle ?? false;
  }

  get errors() {
    return makeArray(this.args.errors);
  }

  // concatErrors(errors) {
  //   return errors.join(", ");
  // }

  <template>
    {{log "errors.gjs" this.errors}}
    <p class="form-kit__errors" id={{@id}} aria-live="assertive" ...attributes>
      {{#each this.errors as |error|}}
        <span>
          {{icon "exclamation-triangle"}}
          {{#if this.withTitle}}
            [{{error.name}}]
          {{/if}}
          {{error.message}}
        </span>
        <br />
      {{/each}}
    </p>
  </template>
}
