import SelectedNameComponent from "select-kit/components/selected-name";
import discourseComputed from "discourse-common/utils/decorators";

export default SelectedNameComponent.extend({
  classNames: ["select-kit-selected-color"],

  @discourseComputed("name")
  footerContent(name) {
    return `<span class="color-preview" style="background:#${name}"></span>`.htmlSafe();
  }
});
