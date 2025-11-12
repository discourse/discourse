import { action, computed } from "@ember/object";
import TagDrop from "discourse/select-kit/components/tag-drop";

export default class DTemplatesTagDrop extends TagDrop {
  @computed("availableTags.[]")
  get topTags() {
    // sort tags descending by count and ascending by name
    return (this.availableTags || []).sort((a, b) => {
      if (a.count !== b.count) {
        return b.count - a.count;
      } // descending
      if (a.name !== b.name) {
        return a.name < b.name ? -1 : 1;
      } // ascending
      return 0;
    });
  }

  search(filter) {
    return (this.content || [])
      .map((tag) => {
        if (tag.id && tag.name) {
          return tag;
        }
        return this.defaultItem(tag, tag);
      })
      .filter((tag) => {
        if (filter == null) {
          return true;
        }

        const tagFilter = filter.toLowerCase();
        return (
          tag.id.toLowerCase().includes(tagFilter) ||
          tag.name.toLowerCase().includes(tagFilter)
        );
      });
  }

  @action
  onChange(tagId, tag) {
    // overrides the action onChange of the parent with the value received in
    // the property onChangeSelectedTag in the handlebars template
    this.onChangeSelectedTag?.(tagId, tag);
  }
}
