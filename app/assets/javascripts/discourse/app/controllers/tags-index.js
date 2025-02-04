import Controller from "@ember/controller";
import { action } from "@ember/object";
import { alias, notEmpty } from "@ember/object/computed";
import { service } from "@ember/service";
import TagUpload from "discourse/components/modal/tag-upload";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class TagsIndexController extends Controller {
  @service dialog;
  @service modal;

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

  @discourseComputed("groupedByCategory", "groupedByTagGroup")
  otherTagsTitleKey(groupedByCategory, groupedByTagGroup) {
    if (!groupedByCategory && !groupedByTagGroup) {
      return "tagging.all_tags";
    } else {
      return "tagging.other_tags";
    }
  }

  @discourseComputed
  actionsMapping() {
    return {
      manageGroups: () => this.send("showTagGroups"),
      uploadTags: () => this.send("showUploader"),
      deleteUnusedTags: () => this.send("deleteUnused"),
    };
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
  showUploader() {
    this.modal.show(TagUpload);
  }

  @action
  deleteUnused() {
    ajax("/tags/unused", { type: "GET" })
      .then((result) => {
        const displayN = 20;
        const tags = result["tags"];

        if (tags.length === 0) {
          this.dialog.alert(i18n("tagging.delete_no_unused_tags"));
          return;
        }

        const joinedTags = tags
          .slice(0, displayN)
          .join(i18n("tagging.tag_list_joiner"));
        const more = Math.max(0, tags.length - displayN);

        const tagsString =
          more === 0
            ? joinedTags
            : i18n("tagging.delete_unused_confirmation_more_tags", {
                count: more,
                tags: joinedTags,
              });

        const message = i18n("tagging.delete_unused_confirmation", {
          count: tags.length,
          tags: tagsString,
        });

        this.dialog.deleteConfirm({
          message,
          confirmButtonLabel: "tagging.delete_unused",
          didConfirm: () => {
            return ajax("/tags/unused", { type: "DELETE" })
              .then(() => this.send("triggerRefresh"))
              .catch(popupAjaxError);
          },
        });
      })
      .catch(popupAjaxError);
  }
}
