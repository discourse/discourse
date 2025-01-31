import Component from "@glimmer/component";
import { get } from "@ember/helper";
import { applyValueTransformer } from "../lib/transformer";
import UserFieldConfirm from "./user-fields/confirm";
import UserFieldDropdown from "./user-fields/dropdown";
import UserFieldMultiselect from "./user-fields/multiselect";
import UserFieldText from "./user-fields/text";

export default class UserField extends Component {
  get components() {
    return applyValueTransformer("user-field-components", {
      confirm: UserFieldConfirm,
      dropdown: UserFieldDropdown,
      multiselect: UserFieldMultiselect,
      text: UserFieldText,
    });
  }

  <template>
    {{#let (get this.components @field.field_type) as |UserFieldComponent|}}
      <UserFieldComponent
        @field={{@field}}
        @value={{@value}}
        @validation={{@validation}}
        ...attributes
      />
    {{/let}}
  </template>
}
