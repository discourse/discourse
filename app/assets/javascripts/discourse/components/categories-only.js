import Component from "@ember/component";
import { equal } from "@ember/object/computed";

export default Component.extend({
  tagName: "",
  noCategoryStyle: equal("siteSettings.category_style", "none")
});
