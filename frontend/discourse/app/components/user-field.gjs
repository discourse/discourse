import Component from "@glimmer/component";
import { get } from "@ember/helper";
import { applyValueTransformer } from "../lib/transformer.js";
import UserFieldConfirm from "./user-fields/confirm.gjs";
import UserFieldDate from "./user-fields/date.gjs";
import UserFieldDropdown from "./user-fields/dropdown.gjs";
import UserFieldMultiselect from "./user-fields/multiselect.gjs";
import UserFieldText from "./user-fields/text.gjs";
import UserFieldTextArea from "./user-fields/textarea.gjs";

export default class UserField extends Component {
  get components() {
    return applyValueTransformer("user-field-components", {
      confirm: UserFieldConfirm,
      dropdown: UserFieldDropdown,
      multiselect: UserFieldMultiselect,
      text: UserFieldText,
      textarea: UserFieldTextArea,
      date: UserFieldDate,
    });
  }

  <template>
    {{#let (get this.components @field.field_type) as |UserFieldComponent|}}
      <UserFieldComponent
        ...attributes
        @field={{@field}}
        @validation={{@validation}}
        @value={{@value}}
      />
    {{/let}}
  </template>
}
