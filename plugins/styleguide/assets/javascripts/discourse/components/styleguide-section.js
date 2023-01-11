import Component from "@ember/component";
import computed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "section",
  classNameBindings: [":styleguide-section", "sectionClass"],

  didReceiveAttrs() {
    this._super(...arguments);
    window.scrollTo(0, 0);
  },

  @computed("section")
  sectionClass(section) {
    if (section) {
      return `${section.id}-examples`;
    }
  },
});
