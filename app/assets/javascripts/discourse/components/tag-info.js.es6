import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { reads, and } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";

export default Component.extend({
  tagName: "",
  loading: false,
  tagInfo: null,
  newSynonyms: null,
  showEditControls: false,
  canAdminTag: reads("currentUser.staff"),
  editSynonymsMode: and("canAdminTag", "showEditControls"),

  @discourseComputed("tagInfo.tag_group_names")
  tagGroupsInfo(tagGroupNames) {
    return I18n.t("tagging.tag_groups_info", {
      count: tagGroupNames.length,
      tag_groups: tagGroupNames.join(", ")
    });
  },

  @discourseComputed("tagInfo.categories")
  categoriesInfo(categories) {
    return I18n.t("tagging.category_restrictions", {
      count: categories.length
    });
  },

  @discourseComputed(
    "tagInfo.tag_group_names",
    "tagInfo.categories",
    "tagInfo.synonyms"
  )
  nothingToShow(tagGroupNames, categories, synonyms) {
    return isEmpty(tagGroupNames) && isEmpty(categories) && isEmpty(synonyms);
  },

  didInsertElement() {
    this._super(...arguments);
    this.loadTagInfo();
  },

  loadTagInfo() {
    if (this.loading) {
      return;
    }
    this.set("loading", true);
    return this.store
      .find("tag-info", this.tag.id)
      .then(result => {
        this.set("tagInfo", result);
        this.set(
          "tagInfo.synonyms",
          result.synonyms.map(s => this.store.createRecord("tag", s))
        );
      })
      .finally(() => this.set("loading", false))
      .catch(popupAjaxError);
  },

  actions: {
    toggleEditControls() {
      this.toggleProperty("showEditControls");
    },

    renameTag() {
      showModal("rename-tag", { model: this.tag });
    },

    deleteTag() {
      this.sendAction("deleteAction", this.tagInfo);
    },

    unlinkSynonym(tag) {
      ajax(`/tag/${this.tagInfo.name}/synonyms/${tag.id}`, {
        type: "DELETE"
      })
        .then(() => this.tagInfo.synonyms.removeObject(tag))
        .catch(popupAjaxError);
    },

    deleteSynonym(tag) {
      bootbox.confirm(
        I18n.t("tagging.delete_synonym_confirm", { tag_name: tag.text }),
        result => {
          if (!result) return;

          tag
            .destroyRecord()
            .then(() => this.tagInfo.synonyms.removeObject(tag))
            .catch(popupAjaxError);
        }
      );
    },

    addSynonyms() {
      bootbox.confirm(
        I18n.t("tagging.add_synonyms_explanation", {
          count: this.newSynonyms.length,
          tag_name: this.tagInfo.name
        }),
        result => {
          if (!result) return;

          ajax(`/tag/${this.tagInfo.name}/synonyms`, {
            type: "POST",
            data: {
              synonyms: this.newSynonyms
            }
          })
            .then(response => {
              if (response.success) {
                this.set("newSynonyms", null);
                this.loadTagInfo();
              } else if (response.failed_tags) {
                bootbox.alert(
                  I18n.t("tagging.add_synonyms_failed", {
                    tag_names: Object.keys(response.failed_tags).join(", ")
                  })
                );
              } else {
                bootbox.alert(I18n.t("generic_error"));
              }
            })
            .catch(popupAjaxError);
        }
      );
    }
  }
});
