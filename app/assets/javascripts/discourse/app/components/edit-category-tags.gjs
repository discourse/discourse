import { action, set } from "@ember/object";
import { and, empty } from "@ember/object/computed";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";

export default class EditCategoryTags extends buildCategoryPanel("tags") {
  @empty("category.allowed_tags") allowedTagsEmpty;
  @empty("category.allowed_tag_groups") allowedTagGroupsEmpty;
  @and("allowedTagsEmpty", "allowedTagGroupsEmpty") disableAllowGlobalTags;

  @action
  onTagGroupChange(rtg, valueArray) {
    // A little strange, but we're using a multi-select component
    // to select a single tag group. This action takes the array
    // and extracts the first value in it.
    set(rtg, "name", valueArray[0]);
  }

  @action
  addRequiredTagGroup() {
    this.category.required_tag_groups.pushObject({
      min_count: 1,
    });
  }

  @action
  deleteRequiredTagGroup(rtg) {
    this.category.required_tag_groups.removeObject(rtg);
  }
}
