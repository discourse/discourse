import Component from "@glimmer/component";

export default class FkControlSelectOption extends Component {
  get isSelected() {
    return this.args.selected === this.args.value;
  }

  <template>
    {{! https://github.com/emberjs/ember.js/issues/19115 }}
    {{#if this.isSelected}}
      <option
        class="d-form-select-option"
        value={{@value}}
        selected
        ...attributes
      >{{yield}}</option>
    {{else}}
      <option
        class="d-form-select-option"
        value={{@value}}
        ...attributes
      >{{yield}}</option>
    {{/if}}
  </template>
}
