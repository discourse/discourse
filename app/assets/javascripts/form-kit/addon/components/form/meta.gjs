import Component from "@glimmer/component";
import FormCharCounter from "form-kit/components/form/char-counter";
import FormErrors from "form-kit/components/form/errors";
import FormText from "form-kit/components/form/text";

export default class FormMeta extends Component {
  get shouldRenderErrors() {
    console.log(this.args.errors);
    return this.args.errors && (this.args.showErrors ?? true);
  }

  get shouldRenderCharCounter() {
    return this.args.maxLength > 0 && !this.args.disabled;
  }

  get shouldRenderMeta() {
    return this.shouldRenderCharCounter || this.shouldRenderErrors;
  }

  <template>
    {{#if this.shouldRenderMeta}}
      <div class="d-form-meta">
        {{#if this.shouldRenderErrors}}
          <FormErrors @id={{@errorId}} @errors={{@errors}} />
        {{else if @description}}
          <FormText>{{@description}}</FormText>
        {{/if}}

        {{#if this.shouldRenderCharCounter}}
          <FormCharCounter @value={{@value}} @maxLength={{@maxLength}} />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
