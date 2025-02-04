import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import SelectedNameComponent from "select-kit/components/selected-name";

@classNames("select-kit-selected-color")
export default class SelectedColor extends SelectedNameComponent {
  @discourseComputed("name")
  footerContent(name) {
    return htmlSafe(
      `<span class="color-preview" style="background:#${name}"></span>`
    );
  }
}
