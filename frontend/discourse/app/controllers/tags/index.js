import Controller from "@ember/controller";
import { action } from "@ember/object";
import { alias, notEmpty } from "@ember/object/computed";
import discourseComputed from "discourse/lib/decorators";
import { optionalRequire } from "discourse/lib/utilities";

export default class TagsIndexController extends Controller {
  sortedByCount = true;
  sortedByName = false;

  @alias("siteSettings.tags_sort_alphabetically") sortAlphabetically;
  @alias("currentUser.staff") canAdminTags;
  @notEmpty("model.extras.categories") groupedByCategory;
  @notEmpty("model.extras.tag_groups") groupedByTagGroup;

  init() {
    super.init(...arguments);

    const isAlphaSort = this.sortAlphabetically;

    this.setProperties({
      sortedByCount: isAlphaSort ? false : true,
      sortedByName: isAlphaSort ? true : false,
      sortProperties: isAlphaSort ? ["id"] : ["totalCount:desc", "id"],
    });
  }

  get TagsAdminDropdownComponent() {
    return optionalRequire("discourse/admin/components/tags-admin-dropdown");
  }

  @discourseComputed("groupedByCategory", "groupedByTagGroup")
  otherTagsTitleKey(groupedByCategory, groupedByTagGroup) {
    if (!groupedByCategory && !groupedByTagGroup) {
      return "tagging.all_tags";
    } else {
      return "tagging.other_tags";
    }
  }

  @action
  sortByCount(event) {
    event?.preventDefault();
    this.setProperties({
      sortProperties: ["totalCount:desc", "id"],
      sortedByCount: true,
      sortedByName: false,
    });
  }

  @action
  sortById(event) {
    event?.preventDefault();
    this.setProperties({
      sortProperties: ["id"],
      sortedByCount: false,
      sortedByName: true,
    });
  }
}
