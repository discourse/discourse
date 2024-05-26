import Component from "@glimmer/component";
import icon from "discourse-common/helpers/d-icon";

export default class ValidationMessages extends Component {
  <template>
    {{#if @node.allValidationMessages}}
      {{icon "exclamation-triangle"}}
      {{#each @node.allValidationMessages as |message|}}
        {{message}}
      {{/each}}
    {{/if}}
  </template>
}
