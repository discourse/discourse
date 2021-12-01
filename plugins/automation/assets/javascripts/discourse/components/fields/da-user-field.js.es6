import { action } from "@ember/object";
import BaseField from "./da-base-field";

export default BaseField.extend({
  @action
  onChangeUsername(usernames) {
    this.set("field.metadata.value", usernames.get("firstObject"));
  },
});
