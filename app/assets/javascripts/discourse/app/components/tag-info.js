import Component from "@ember/component";
import { action } from "@ember/object";
import { and, reads } from "@ember/object/computed";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

@tagName("")
export default class TagInfo extends Component {
  @service dialog;
  @service router;

  loading = false;
  tagInfo = null;
  newSynonyms = null;
  showEditControls = false;
  editing = false;
  newTagName = null;
  newTagDescription = null;

  @reads("currentUser.staff") canAdminTag;
  @and("canAdminTag", "showEditControls") editSynonymsMode;

  @discourseComputed("tagInfo.tag_group_names")
  tagGroupsInfo(tagGroupNames) {
    return i18n("tagging.tag_groups_info", {
      count: tagGroupNames.length,
      tag_groups: tagGroupNames.join(", "),
    });
  }

  @discourseComputed("tagInfo.categories")
  categoriesInfo(categories) {
    return i18n("tagging.category_restrictions", {
      count: categories.length,
    });
  }

  @discourseComputed(
    "tagInfo.tag_group_names",
    "tagInfo.categories",
    "tagInfo.synonyms"
  )
  nothingToShow(tagGroupNames, categories, synonyms) {
    return isEmpty(tagGroupNames) && isEmpty(categories) && isEmpty(synonyms);
  }

  @discourseComputed("newTagName")
  updateDisabled(newTagName) {
    const filterRegexp = new RegExp(this.site.tags_filter_regexp, "g");
    newTagName = newTagName ? newTagName.replace(filterRegexp, "").trim() : "";
    return newTagName.length === 0;
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.loadTagInfo();
  }

  didUpdateAttrs() {
    super.didUpdateAttrs(...arguments);
    this.set("tagInfo", null);
    this.loadTagInfo();
  }

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
  }

  @action
  edit(event) {
    event?.preventDefault();
    this.tagInfo.set(
      "descriptionWithNewLines",
      this.tagInfo.description?.replaceAll("<br>", "\n")
    );
    this.setProperties({
      editing: true,
      newTagName: this.tag.id,
      newTagDescription: this.tagInfo.description,
    });
  }

  @action
  unlinkSynonym(tag, event) {
    event?.preventDefault();
    ajax(`/tag/${this.tagInfo.name}/synonyms/${tag.id}`, {
      type: "DELETE",
    })
      .then(() => this.tagInfo.synonyms.removeObject(tag))
      .catch(popupAjaxError);
  }

  @action
  deleteSynonym(tag, event) {
    event?.preventDefault();

    this.dialog.yesNoConfirm({
      message: i18n("tagging.delete_synonym_confirm", {
        tag_name: tag.text,
      }),
      didConfirm: () => {
        return tag
          .destroyRecord()
          .then(() => this.tagInfo.synonyms.removeObject(tag))
          .catch(popupAjaxError);
      },
    });
  }

  @action
  toggleEditControls() {
    this.toggleProperty("showEditControls");
  }

  @action
  cancelEditing() {
    this.set("editing", false);
  }

  @action
  finishedEditing() {
    const oldTagName = this.tag.id;
    this.newTagDescription = this.newTagDescription?.replaceAll("\n", "<br>");
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
  }

  @action
  deleteTag() {
    const numTopics =
      this.get("list.topic_list.tags.firstObject.topic_count") || 0;

    let confirmText =
      numTopics === 0
        ? i18n("tagging.delete_confirm_no_topics")
        : i18n("tagging.delete_confirm", { count: numTopics });

    if (this.tagInfo.synonyms.length > 0) {
      confirmText +=
        " " +
        i18n("tagging.delete_confirm_synonyms", {
          count: this.tagInfo.synonyms.length,
        });
    }

    this.dialog.deleteConfirm({
      message: confirmText,
      didConfirm: async () => {
        try {
          await this.tag.destroyRecord();
          this.router.transitionTo("tags.index");
        } catch {
          this.dialog.alert(i18n("generic_error"));
        }
      },
    });
  }

  @action
  addSynonyms() {
    this.dialog.confirm({
      message: htmlSafe(
        i18n("tagging.add_synonyms_explanation", {
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
                i18n("tagging.add_synonyms_failed", {
                  tag_names: Object.keys(response.failed_tags).join(", "),
                })
              );
            } else {
              this.dialog.alert(i18n("generic_error"));
            }
          })
          .catch(popupAjaxError);
      },
    });
  }
}
