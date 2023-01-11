import SelectedNameComponent from "select-kit/components/selected-name";
import discourseComputed from "discourse-common/utils/decorators";
import { htmlSafe } from "@ember/template";

export default SelectedNameComponent.extend({
  classNames: ["select-kit-selected-color"],

  @discourseComputed("name")
  footerContent(name) {
    return htmlSafe(
      `<span class="color-preview" style="background:#${name}"></span>`
    );
  },
});
