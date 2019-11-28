import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import { observes } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { reads, and } from "@ember/object/computed";

export default Component.extend({
  tagName: "",
  loading: false,
  tagInfo: null,
  newSynonyms: null,
  showEditControls: false,
  canAdminTag: reads("currentUser.staff"),
  editSynonymsMode: and("canAdminTag", "showEditControls"),

  @observes("expanded")
  toggleExpanded() {
    if (this.expanded && !this.tagInfo) {
      this.loadTagInfo();
    }
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
          result.synonyms.map(s => {
            return this.store.createRecord("tag", s);
          })
        );
      })
      .finally(() => this.set("loading", false));
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
      ajax(`/tags/${this.tagInfo.name}/synonyms/${tag.id}`, {
        type: "DELETE"
      })
        .then(() => this.tagInfo.synonyms.removeObject(tag))
        .catch(() => bootbox.alert(I18n.t("generic_error")));
    },

    deleteSynonym(tag) {
      tag
        .destroyRecord()
        .then(() => this.tagInfo.synonyms.removeObject(tag))
        .catch(() => bootbox.alert(I18n.t("generic_error")));
    },

    addSynonyms() {
      ajax(`/tags/${this.tagInfo.name}/synonyms`, {
        type: "POST",
        data: {
          synonyms: this.newSynonyms
        }
      })
        .then(result => {
          if (result.success) {
            this.set("newSynonyms", null);
            this.loadTagInfo();
          } else if (result.failed_tags) {
            bootbox.alert(
              I18n.t("tagging.add_synonyms_failed", {
                tag_names: Object.keys(result.failed_tags).join(", ")
              })
            );
          } else {
            bootbox.alert(I18n.t("generic_error"));
          }
        })
        .catch(popupAjaxError);
    }
  }
});
