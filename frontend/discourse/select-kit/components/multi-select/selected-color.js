import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import SelectedNameComponent from "discourse/select-kit/components/selected-name";

@classNames("select-kit-selected-color")
export default class SelectedColor extends SelectedNameComponent {
  @computed("name")
  get footerContent() {
    return htmlSafe(
      `<span class="color-preview" style="background:#${this.name}"></span>`
    );
  }
}
