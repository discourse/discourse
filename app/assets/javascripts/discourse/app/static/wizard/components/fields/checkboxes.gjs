import Component, { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import icon from "discourse/helpers/d-icon";

export default class Checkboxes extends Component {
  init(...args) {
    super.init(...args);
    this.set("field.value", this.field.value || []);

    for (let choice of this.field.choices) {
      if (this.field.value.includes(choice.id)) {
        set(choice, "checked", true);
      }
    }
  }

  @action
  changed(checkbox) {
    let newFieldValue = this.field.value;
    const checkboxValue = checkbox.parentElement
      .getAttribute("value")
      .toLowerCase();

    if (checkbox.checked) {
      newFieldValue.push(checkboxValue);
    } else {
      const index = newFieldValue.indexOf(checkboxValue);
      if (index > -1) {
        newFieldValue.splice(index, 1);
      }
    }
    this.set("field.value", newFieldValue);
  }

  <template>
    {{#each this.field.choices as |c|}}
      <div class="checkbox-field-choice {{this.fieldClass}}">
        <label id={{c.id}} value={{c.label}}>
          <Input
            @type="checkbox"
            class="wizard-container__checkbox"
            @checked={{c.checked}}
            {{on "click" this.changed}}
          />
          {{#if c.icon}}
            {{icon c.icon}}
          {{/if}}
          {{c.label}}
        </label>
      </div>
    {{/each}}
  </template>
}
