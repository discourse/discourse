import Component from "@glimmer/component";
import DTooltip from "float-kit/components/d-tooltip";

export default class FKTooltip extends Component {
  get isComponentTooltip() {
    return typeof this.args.field.tooltip === "object";
  }

  <template>
    {{#if @field.tooltip}}
      {{#if this.isComponentTooltip}}
        <@field.tooltip />
      {{else}}
        <DTooltip
          class="form-kit__tooltip"
          @icon="circle-question"
          @content={{@field.tooltip}}
        />
      {{/if}}
    {{/if}}
  </template>
}
