import DiscourseURL from "discourse/lib/url";
import MiniTagChooser from "select-kit/components/mini-tag-chooser";
import { makeArray } from "discourse-common/lib/helpers";
import { action } from "@ember/object";

export default MiniTagChooser.extend({
  pluginApiIdentifiers: ["tags-intersection-chooser"],
  attributeBindings: ["selectKit.options.categoryId:category-id"],
  classNames: ["tags-intersection-chooser"],

  mainTag: null,
  additionalTags: null,

  didReceiveAttrs() {
    this._super(...arguments);

    this.set(
      "value",
      makeArray(this.mainTag).concat(makeArray(this.additionalTags))
    );
  },

  @action
  onChange(tags) {
    if (tags.includes(this.mainTag)) {
      const remainingTags = tags.filter((t) => t !== this.mainTag);

      if (remainingTags.length >= 1) {
        DiscourseURL.routeTo(
          `/tags/intersection/${this.mainTag}/${remainingTags.join("/")}`
        );
      } else {
        DiscourseURL.routeTo("/tags");
      }
    } else {
      if (tags.length >= 2) {
        DiscourseURL.routeTo(`/tags/intersection/${tags.join("/")}`);
      } else {
        DiscourseURL.routeTo("/tags");
      }
    }
  },
});
