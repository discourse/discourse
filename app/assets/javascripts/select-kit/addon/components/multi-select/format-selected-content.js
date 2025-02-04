import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import UtilsMixin from "select-kit/mixins/utils";

@tagName("")
export default class FormatSelectedContent extends Component.extend(
  UtilsMixin
) {
  content = null;
  selectKit = null;

  @computed("content")
  get formattedContent() {
    if (this.content) {
      return makeArray(this.content)
        .map((c) => this.getName(c))
        .join(", ");
    } else {
      return this.getName(this.selectKit.noneItem);
    }
  }
}
