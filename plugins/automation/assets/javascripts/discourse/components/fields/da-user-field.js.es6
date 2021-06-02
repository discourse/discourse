import { action } from "@ember/object";
import Component from "@ember/component";

export default Component.extend({
  tagName: "",

  @action
  onChangeUsername(usernames) {
    this.set("field.metadata.username", usernames.get("firstObject"));
  }
});
