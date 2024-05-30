import Component from "@glimmer/component";

export default class FormFieldset extends Component {
  <template>
    <fieldset class="d-form-fieldset">
      {{#if @legend}}
        <legend class="d-form-field__label">{{@legend}}</legend>
      {{/if}}

      {{yield}}
    </fieldset>
  </template>
}
