import { buildCategoryPanel } from "discourse/components/edit-category-panel";

export default buildCategoryPanel("tags", {
  allowedTagsEmpty: Ember.computed.empty("category.allowed_tags"),
  allowedTagGroupsEmpty: Ember.computed.empty("category.allowed_tag_groups"),
  disableAllowGlobalTags: Ember.computed.and(
    "allowedTagsEmpty",
    "allowedTagGroupsEmpty"
  )
});
