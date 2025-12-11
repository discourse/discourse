import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { alias, notEmpty } from "@ember/object/computed";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { optionalRequire } from "discourse/lib/utilities";

export default class TagsIndexController extends Controller {
  @service router;

  @tracked bulkTagInput = "";
  @tracked isCreatingTags = false;
  @tracked bulkCreateResults = null;

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

  get canCreateTags() {
    return this.bulkTagInput && this.bulkTagInput.trim().length > 0;
  }

  get hasFailedTags() {
    return (
      this.bulkCreateResults?.failed &&
      Object.keys(this.bulkCreateResults.failed).length > 0
    );
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

  @action
  async bulkCreateTags(event) {
    event?.preventDefault();

    if (!this.bulkTagInput || this.bulkTagInput.trim().length === 0) {
      return;
    }

    const tagNames = this.bulkTagInput
      .split(/[,\n\r]+/)
      .map((tag) => tag.trim())
      .filter((tag) => tag.length > 0);

    if (tagNames.length === 0) {
      return;
    }

    this.isCreatingTags = true;

    try {
      const response = await ajax("/tags/bulk_create.json", {
        type: "POST",
        data: { tag_names: tagNames },
      });

      this.bulkTagInput = "";
      this.bulkCreateResults = response;
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isCreatingTags = false;
    }
  }

  @action
  dismissResults() {
    this.bulkCreateResults = null;
  }
}
