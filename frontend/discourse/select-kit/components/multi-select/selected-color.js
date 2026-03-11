import { computed } from "@ember/object";
import { trustHTML } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import SelectedNameComponent from "discourse/select-kit/components/selected-name";

@classNames("select-kit-selected-color")
export default class SelectedColor extends SelectedNameComponent {
  @computed("name")
  get footerContent() {
    return trustHTML(
      `<span class="color-preview" style="background:#${this.name}"></span>`
    );
  }
}
