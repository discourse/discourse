/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { trustHTML } from "@ember/template";
import {
  attributeBindings,
  classNameBindings,
  tagName,
} from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@tagName("button")
@attributeBindings("style", "title", "ariaLabel:aria-label")
@classNameBindings(":colorpicker", "isUsed:used-color:unused-color")
export default class DColorPickerChoice extends Component {
  @computed("color", "usedColors")
  get isUsed() {
    return (this.usedColors || []).includes(this.color.toUpperCase());
  }

  @computed("isUsed")
  get title() {
    return this.isUsed ? i18n("category.already_used") : null;
  }

  @computed("color")
  get style() {
    return trustHTML(`background-color: #${this.color};`);
  }

  click(e) {
    e.preventDefault();
    this.selectColor(this.color);
  }
}
