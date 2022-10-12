import { and, reads } from "@ember/object/computed";
import Component from "@ember/component";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";

export default Component.extend({
  dialog: service(),
  tagName: "",
  loading: false,
  tagInfo: null,
  newSynonyms: null,
  showEditControls: false,
  canAdminTag: reads("currentUser.staff"),
  editSynonymsMode: and("canAdminTag", "showEditControls"),
  editing: false,
  newTagName: null,
  newTagDescription: null,
  router: service(),

  @discourseComputed("tagInfo.tag_group_names")
  tagGroupsInfo(tagGroupNames) {
    return I18n.t("tagging.tag_groups_info", {
      count: tagGroupNames.length,
      tag_groups: tagGroupNames.join(", "),
    });
  },

  @discourseComputed("tagInfo.categories")
  categoriesInfo(categories) {
    return I18n.t("tagging.category_restrictions", {
      count: categories.length,
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

  @discourseComputed("newTagName")
  updateDisabled(newTagName) {
    const filterRegexp = new RegExp(this.site.tags_filter_regexp, "g");
    newTagName = newTagName ? newTagName.replace(filterRegexp, "").trim() : "";
    return newTagName.length === 0;
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
      .then((result) => {
        this.set("tagInfo", result);
        this.set(
          "tagInfo.synonyms",
          result.synonyms.map((s) => this.store.createRecord("tag", s))
        );
      })
      .finally(() => this.set("loading", false))
      .catch(popupAjaxError);
  },

  @action
  edit(event) {
    event?.preventDefault();
    this.setProperties({
      editing: true,
      newTagName: this.tag.id,
      newTagDescription: this.tagInfo.description,
    });
  },

  @action
  unlinkSynonym(tag, event) {
    event?.preventDefault();
    ajax(`/tag/${this.tagInfo.name}/synonyms/${tag.id}`, {
      type: "DELETE",
    })
      .then(() => this.tagInfo.synonyms.removeObject(tag))
      .catch(popupAjaxError);
  },

  @action
  deleteSynonym(tag, event) {
    event?.preventDefault();

    this.dialog.yesNoConfirm({
      message: I18n.t("tagging.delete_synonym_confirm", {
        tag_name: tag.text,
      }),
      didConfirm: () => {
        return tag
          .destroyRecord()
          .then(() => this.tagInfo.synonyms.removeObject(tag))
          .catch(popupAjaxError);
      },
    });
  },

  actions: {
    toggleEditControls() {
      this.toggleProperty("showEditControls");
    },

    cancelEditing() {
      this.set("editing", false);
    },

    finishedEditing() {
      const oldTagName = this.tag.id;
      this.tag
        .update({ id: this.newTagName, description: this.newTagDescription })
        .then((result) => {
          this.set("editing", false);
          this.tagInfo.set("description", this.newTagDescription);
          if (
            result.responseJson.tag &&
            oldTagName !== result.responseJson.tag.id
          ) {
            this.router.transitionTo("tag.show", result.responseJson.tag.id);
          }
        })
        .catch(popupAjaxError);
    },

    deleteTag() {
      this.deleteAction(this.tagInfo);
    },

    addSynonyms() {
      this.dialog.confirm({
        message: htmlSafe(
          I18n.t("tagging.add_synonyms_explanation", {
            count: this.newSynonyms.length,
            tag_name: this.tagInfo.name,
          })
        ),
        didConfirm: () => {
          return ajax(`/tag/${this.tagInfo.name}/synonyms`, {
            type: "POST",
            data: {
              synonyms: this.newSynonyms,
            },
          })
            .then((response) => {
              if (response.success) {
                this.set("newSynonyms", null);
                this.loadTagInfo();
              } else if (response.failed_tags) {
                this.dialog.alert(
                  I18n.t("tagging.add_synonyms_failed", {
                    tag_names: Object.keys(response.failed_tags).join(", "),
                  })
                );
              } else {
                this.dialog.alert(I18n.t("generic_error"));
              }
            })
            .catch(popupAjaxError);
        },
      });
    },
  },
});
