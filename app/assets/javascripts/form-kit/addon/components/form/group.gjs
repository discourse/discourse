import Component from "@glimmer/component";
import concatClass from "discourse/helpers/concat-class";
import Label from "../label";

export default class FormGroup extends Component {
  <template>
    <div class={{concatClass "form-group"}}>
      {{#if @label}}
        <Label @label={{@label}} @for={{@for}} class="d-block" ...attributes />
      {{/if}}

      {{#if @help}}
        <p class="d-form-field__info">{{@help}}</p>
      {{/if}}

      <div>
        {{yield}}

        {{#if @description}}
          <div class="d-form-field__meta">
            <p class="d-form-field__meta-text">{{@description}}</p>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
