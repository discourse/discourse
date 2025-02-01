import UserFieldBase from "./base";
export default class UserFieldDropdown extends UserFieldBase {
  updateValue(newValue) {
    this.value = newValue;
  }
}
