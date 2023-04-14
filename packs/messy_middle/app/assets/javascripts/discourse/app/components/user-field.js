import Component from "@glimmer/component";
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

export default class UserFieldComponent extends Component {
  get userFieldComponent() {
    return COMPONENTS[this.args.field.field_type];
  }
}
