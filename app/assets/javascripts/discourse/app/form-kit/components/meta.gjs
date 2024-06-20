import Component from "@glimmer/component";
import FKCharCounter from "discourse/form-kit/components/char-counter";
import FKErrors from "discourse/form-kit/components/errors";
import FKText from "discourse/form-kit/components/text";

export default class FKMeta extends Component {
  get shouldRenderErrors() {
    return this.args.field.hasErrors && (this.args.showErrors ?? true);
  }

  get shouldRenderCharCounter() {
    return this.args.field.maxLength > 0 && !this.args.field.disabled;
  }

  get shouldRenderMeta() {
    return (
      this.showMeta &&
      (this.shouldRenderCharCounter ||
        this.shouldRenderErrors ||
        this.args.description?.length)
    );
  }

  get showMeta() {
    return this.args.showMeta ?? true;
  }

  <template>
    {{#if this.shouldRenderMeta}}
      <div class="form-kit__meta">
        {{#if this.shouldRenderErrors}}
          <FKErrors @id={{@field.errorId}} @fields={{@field}} />
        {{else if @description}}
          <FKText class="form-kit__meta-description">{{@description}}</FKText>
        {{/if}}

        {{#if this.shouldRenderCharCounter}}
          <FKCharCounter @value={{@value}} @maxLength={{@field.maxLength}} />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
