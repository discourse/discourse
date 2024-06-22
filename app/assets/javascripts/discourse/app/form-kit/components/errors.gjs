import Component from "@glimmer/component";
import icon from "discourse-common/helpers/d-icon";
import { makeArray } from "discourse-common/lib/helpers";

export default class FKErrors extends Component {
  get withTitle() {
    return this.args.withTitle ?? false;
  }

  get fields() {
    return makeArray(this.args.fields);
  }

  concatErrors(errors) {
    return errors.join(", ");
  }

  <template>
    <p class="form-kit__errors" id={{@id}} aria-live="assertive" ...attributes>
      {{#each this.fields as |field|}}
        {{#if field.hasErrors}}
          <span>
            {{icon "exclamation-triangle"}}
            {{#if this.withTitle}}
              [{{field.title}}]
            {{/if}}
            {{this.concatErrors field.visibleErrors}}
          </span>
          <br />
        {{/if}}
      {{/each}}
    </p>
  </template>
}
