import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  tagName: "span",
  classNames: ["group-info-details"],

  @computed("group.full_name", "group.title")
  showFullName(fullName, title) {
    return fullName && fullName.length && fullName !== title;
  }
});
