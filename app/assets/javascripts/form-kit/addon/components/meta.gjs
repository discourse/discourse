import Component from "@glimmer/component";
import FKCharCounter from "form-kit/components/char-counter";
import FKErrors from "form-kit/components/errors";
import FKText from "form-kit/components/text";

export default class FKMeta extends Component {
  get shouldRenderErrors() {
    return this.args.hasErrors && (this.args.showErrors ?? true);
  }

  get shouldRenderCharCounter() {
    return this.args.field.maxLength > 0 && !this.args.field.disabled;
  }

  get shouldRenderMeta() {
    return (
      this.showMeta && (this.shouldRenderCharCounter || this.shouldRenderErrors)
    );
  }

  get showMeta() {
    return this.args.showMeta ?? true;
  }

  <template>
    {{#if this.shouldRenderMeta}}
      <div class="form-kit__meta">
        {{#if this.shouldRenderErrors}}
          <FKErrors @id={{@errorId}} @errors={{@errors}} />
        {{else if @description}}
          <FKText>{{@description}}</FKText>
        {{/if}}

        {{#if this.shouldRenderCharCounter}}
          <FKCharCounter @value={{@value}} @maxLength={{@field.maxLength}} />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
