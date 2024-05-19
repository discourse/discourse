import Component from "@glimmer/component";
import concatClass from "discourse/helpers/concat-class";

export default class Label extends Component {
  <template>
    <label class={{concatClass "d-form-field__label"}} for={{@name}}>
      {{@label}}
      {{#if @optional}}
        <span class="d-form-field__optional">(Optional)</span>
      {{/if}}
    </label>
  </template>
}
