import { htmlSafe } from "@ember/template";
import discourseComputed from "discourse-common/utils/decorators";
import SelectedNameComponent from "select-kit/components/selected-name";

export default SelectedNameComponent.extend({
  classNames: ["select-kit-selected-color"],

  @discourseComputed("name")
  footerContent(name) {
    return htmlSafe(
      `<span class="color-preview" style="background:#${name}"></span>`
    );
  },
});
