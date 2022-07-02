import { reads } from "@ember/object/computed";
import Component from "@ember/component";
import { computed } from "@ember/object";

export default Component.extend({
  tagName: "",
  selectedTags: reads("collection.content.selectedTags.[]"),

  tags: computed("selectedTags.[]", "selectKit.filter", function () {
    if (!this.selectedTags) {
      return [];
    }

    let tags = this.selectedTags;
    if (tags.length >= 20 && this.selectKit.filter) {
      tags = tags.filter((t) => t.indexOf(this.selectKit.filter) >= 0);
    } else if (tags.length >= 20) {
      tags = tags.slice(0, 20);
    }

    return tags.map((selectedTag) => {
      return {
        value: selectedTag,
        classNames: "selected-tag",
      };
    });
  }),
});
