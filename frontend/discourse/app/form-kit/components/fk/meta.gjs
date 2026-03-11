import Component from "@glimmer/component";
import FKCharCounter from "discourse/form-kit/components/fk/char-counter";
import FKErrors from "discourse/form-kit/components/fk/errors";

export default class FKMeta extends Component {
  get shouldRenderCharCounter() {
    return this.args.field.maxLength > 0 && !this.args.field.disabled;
  }

  get shouldRenderMeta() {
    return this.showMeta && (this.shouldRenderCharCounter || this.args.error);
  }

  get showMeta() {
    return this.args.showMeta ?? true;
  }

  <template>
    {{#if this.shouldRenderMeta}}
      <div class="form-kit__meta">
        {{#if @error}}
          <FKErrors @id={{@field.errorId}} @error={{@error}} />
        {{/if}}

        {{#if this.shouldRenderCharCounter}}
          <FKCharCounter
            @value={{@field.value}}
            @minLength={{@field.minLength}}
            @maxLength={{@field.maxLength}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
