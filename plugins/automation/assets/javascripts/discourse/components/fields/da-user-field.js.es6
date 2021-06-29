import { action } from "@ember/object";
import BaseField from "./da-base-field";
import { reads } from "@ember/object/computed";

export default BaseField.extend({
  fieldValue: reads("field.metadata.username"),

  @action
  onChangeUsername(usernames) {
    this.set("field.metadata.username", usernames.get("firstObject"));
  }
});
