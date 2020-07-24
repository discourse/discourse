import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",
  category: null,
  listType: "normal",

  @discourseComputed("category.isHidden", "category.hasMuted", "listType")
  isHidden(isHiddenCategory, hasMuted, listType) {
    return (
      (isHiddenCategory && listType === "normal") ||
      (!hasMuted && listType === "muted")
    );
  },

  @discourseComputed("category.isMuted", "listType")
  isMuted(isMutedCategory, listType) {
    return (
      (isMutedCategory && listType === "normal") ||
      (!isMutedCategory && listType === "muted")
    );
  }
});
