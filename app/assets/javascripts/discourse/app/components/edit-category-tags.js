import { empty, and } from "@ember/object/computed";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";

export default buildCategoryPanel("tags", {
  allowedTagsEmpty: empty("category.allowed_tags"),
  allowedTagGroupsEmpty: empty("category.allowed_tag_groups"),
  disableAllowGlobalTags: and("allowedTagsEmpty", "allowedTagGroupsEmpty")
});
