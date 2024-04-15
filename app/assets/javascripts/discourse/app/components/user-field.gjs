import { get } from "@ember/helper";
import UserFieldConfirm from "./user-fields/confirm";
import UserFieldDropdown from "./user-fields/dropdown";
import UserFieldMultiselect from "./user-fields/multiselect";
import UserFieldText from "./user-fields/text";

const COMPONENTS = {
  confirm: UserFieldConfirm,
  dropdown: UserFieldDropdown,
  multiselect: UserFieldMultiselect,
  text: UserFieldText,
};

const UserField = <template>
  {{#let (get COMPONENTS @field.field_type) as |Component|}}
    <Component
      @field={{@field}}
      @value={{@value}}
      @validation={{@validation}}
      ...attributes
    />
  {{/let}}
</template>;

export default UserField;
