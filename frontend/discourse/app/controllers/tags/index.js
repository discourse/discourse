import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed, set } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import autosize from "autosize";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { optionalRequire } from "discourse/lib/utilities";

export default class TagsIndexController extends Controller {
  @service router;

  @tracked bulkTagInput = "";
  @tracked isCreatingTags = false;
  @tracked bulkCreateResults = null;

  bulkTagTextarea = null;

  sortedByCount = true;
  sortedByName = false;

  init() {
    super.init(...arguments);

    const isAlphaSort = this.sortAlphabetically;

    this.setProperties({
      sortedByCount: isAlphaSort ? false : true,
      sortedByName: isAlphaSort ? true : false,
      sortProperties: isAlphaSort ? ["name"] : ["totalCount:desc", "name"],
    });
  }

  @computed("siteSettings.tags_sort_alphabetically")
  get sortAlphabetically() {
    return this.siteSettings?.tags_sort_alphabetically;
  }

  set sortAlphabetically(value) {
    set(this, "siteSettings.tags_sort_alphabetically", value);
  }

  @computed("currentUser.staff")
  get canAdminTags() {
    return this.currentUser?.staff;
  }

  set canAdminTags(value) {
    set(this, "currentUser.staff", value);
  }

  @computed("model.extras.categories.length")
  get groupedByCategory() {
    return !isEmpty(this.model?.extras?.categories);
  }

  @computed("model.extras.tag_groups.length")
  get groupedByTagGroup() {
    return !isEmpty(this.model?.extras?.tag_groups);
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

  @computed("groupedByCategory", "groupedByTagGroup")
  get otherTagsTitleKey() {
    if (!this.groupedByCategory && !this.groupedByTagGroup) {
      return "tagging.all_tags";
    } else {
      return "tagging.other_tags";
    }
  }

  @action
  sortByCount(event) {
    event?.preventDefault();
    this.setProperties({
      sortProperties: ["totalCount:desc", "name"],
      sortedByCount: true,
      sortedByName: false,
    });
  }

  @action
  sortByName(event) {
    event?.preventDefault();
    this.setProperties({
      sortProperties: ["name"],
      sortedByCount: false,
      sortedByName: true,
    });
  }

  @action
  registerTextarea(element) {
    this.bulkTagTextarea = element;
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

      schedule("afterRender", () => {
        if (this.bulkTagTextarea) {
          autosize.update(this.bulkTagTextarea);
        }
      });
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
