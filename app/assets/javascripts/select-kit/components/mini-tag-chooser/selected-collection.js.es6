import Component from "@ember/component";
import { computed } from "@ember/object";
import { reads, notEmpty } from "@ember/object/computed";

export default Component.extend({
  layoutName:
    "select-kit/templates/components/mini-tag-chooser/selected-collection",
  classNames: ["mini-tag-chooser-selected-collection", "selected-tags"],
  isVisible: notEmpty("selectedTags.[]"),
  selectedTags: reads("collection.content.selectedTags.[]"),
  highlightedTag: reads("collection.content.highlightedTag"),

  tags: computed(
    "selectedTags.[]",
    "highlightedTag",
    "selectKit.filter",
    function() {
      if (!this.selectedTags) {
        return [];
      }

      let tags = this.selectedTags;
      if (tags.length >= 20 && this.selectKit.filter) {
        tags = tags.filter(t => t.indexOf(this.selectKit.filter) >= 0);
      } else if (tags.length >= 20) {
        tags = tags.slice(0, 20);
      }

      tags = tags.map(selectedTag => {
        const classNames = ["selected-tag"];
        if (selectedTag === this.highlightedTag) {
          classNames.push("is-highlighted");
        }

        return {
          value: selectedTag,
          classNames: classNames.join(" ")
        };
      });

      return tags;
    }
  ),

  actions: {
    deselectTag(tag) {
      return this.selectKit.deselect(tag);
    }
  }
});
