import Component from "@ember/component";
import { computed } from "@ember/object";
import layout from "select-kit/templates/components/multi-select/format-selected-content";
import { makeArray } from "discourse-common/lib/helpers";
import UtilsMixin from "select-kit/mixins/utils";

export default Component.extend(UtilsMixin, {
  tagName: "",
  layout,
  content: null,
  selectKit: null,

  formatedContent: computed("content", function () {
    if (this.content) {
      return makeArray(this.content)
        .map((c) => this.getName(c))
        .join(", ");
    } else {
      return this.getName(this.selectKit.noneItem);
    }
  }),
});
