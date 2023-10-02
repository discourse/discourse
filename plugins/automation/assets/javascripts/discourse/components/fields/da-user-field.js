import { action } from "@ember/object";
import BaseField from "./da-base-field";

export default class UserField extends BaseField {
  @action
  onChangeUsername(usernames) {
    this.set("field.metadata.value", usernames.get("firstObject"));
  }
}
