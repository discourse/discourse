import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import computed from "ember-addons/ember-computed-decorators";

export default buildCategoryPanel("tags", {
  allowedTagsEmpty: Ember.computed.empty("category.allowed_tags"),
  allowedTagGroupsEmpty: Ember.computed.empty("category.allowed_tag_groups"),
  disableAllowGlobalTags: Ember.computed.and(
    "allowedTagsEmpty",
    "allowedTagGroupsEmpty"
  )
});
