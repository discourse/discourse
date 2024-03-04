import discourseComputed from "discourse-common/utils/decorators";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

export default SelectKitRowComponent.extend({
  classNames: ["tag-row"],

  @discourseComputed("item")
  isTag(item) {
    return item.id !== "no-tags" && item.id !== "all-tags";
  },
});
