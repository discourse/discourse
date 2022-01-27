import { alias, notEmpty } from "@ember/object/computed";
import Controller from "@ember/controller";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";

export default Controller.extend({
  sortedByCount: true,
  sortedByName: false,

  canAdminTags: alias("currentUser.staff"),
  groupedByCategory: notEmpty("model.extras.categories"),
  groupedByTagGroup: notEmpty("model.extras.tag_groups"),

  init() {
    this._super(...arguments);

    this.sortProperties = ["totalCount:desc", "id"];
  },

  @discourseComputed("groupedByCategory", "groupedByTagGroup")
  otherTagsTitleKey(groupedByCategory, groupedByTagGroup) {
    if (!groupedByCategory && !groupedByTagGroup) {
      return "tagging.all_tags";
    } else {
      return "tagging.other_tags";
    }
  },

  @discourseComputed
  actionsMapping() {
    return {
      manageGroups: () => this.send("showTagGroups"),
      uploadTags: () => this.send("showUploader"),
      deleteUnusedTags: () => this.send("deleteUnused"),
    };
  },

  actions: {
    sortByCount() {
      this.setProperties({
        sortProperties: ["totalCount:desc", "id"],
        sortedByCount: true,
        sortedByName: false,
      });
    },

    sortById() {
      this.setProperties({
        sortProperties: ["id"],
        sortedByCount: false,
        sortedByName: true,
      });
    },

    showUploader() {
      showModal("tag-upload");
    },

    deleteUnused() {
      ajax("/tags/unused", { type: "GET" })
        .then((result) => {
          const displayN = 20;
          const tags = result["tags"];

          if (tags.length === 0) {
            bootbox.alert(I18n.t("tagging.delete_no_unused_tags"));
            return;
          }

          const joinedTags = tags
            .slice(0, displayN)
            .join(I18n.t("tagging.tag_list_joiner"));
          const more = Math.max(0, tags.length - displayN);

          const tagsString =
            more === 0
              ? joinedTags
              : I18n.t("tagging.delete_unused_confirmation_more_tags", {
                  count: more,
                  tags: joinedTags,
                });

          const string = I18n.t("tagging.delete_unused_confirmation", {
            count: tags.length,
            tags: tagsString,
          });

          bootbox.confirm(
            string,
            I18n.t("tagging.cancel_delete_unused"),
            I18n.t("tagging.delete_unused"),
            (proceed) => {
              if (proceed) {
                ajax("/tags/unused", { type: "DELETE" })
                  .then(() => this.send("triggerRefresh"))
                  .catch(popupAjaxError);
              }
            }
          );
        })
        .catch(popupAjaxError);
    },
  },
});
