import Component from "@ember/component";
import { sort } from "@ember/object/computed";
import { classNameBindings } from "@ember-decorators/component";
import Category from "discourse/models/category";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

@classNameBindings(
  ":tags-list",
  ":tag-list",
  "categoryClass",
  "tagGroupNameClass"
)
export default class TagList extends Component {
  isPrivateMessage = false;

  @sort("tags", "sortProperties") sortedTags;

  @discourseComputed("titleKey")
  title(titleKey) {
    return titleKey && i18n(titleKey);
  }

  @discourseComputed("categoryId")
  category(categoryId) {
    return categoryId && Category.findById(categoryId);
  }

  @discourseComputed("category.fullSlug")
  categoryClass(slug) {
    return slug && `tag-list-${slug}`;
  }

  @discourseComputed("tagGroupName")
  tagGroupNameClass(groupName) {
    if (groupName) {
      groupName = groupName
        .replace(/\s+/g, "-")
        .replace(/[!\"#$%&'\(\)\*\+,\.\/:;<=>\?\@\[\\\]\^`\{\|\}~]/g, "")
        .toLowerCase();
      return groupName && `tag-group-${groupName}`;
    }
  }
}
