import Component, { Textarea } from "@ember/component";
import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { and, reads } from "@ember/object/computed";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import TextField from "discourse/components/text-field";
import basePath from "discourse/helpers/base-path";
import categoryLink from "discourse/helpers/category-link";
import icon from "discourse/helpers/d-icon";
import discourseTag from "discourse/helpers/discourse-tag";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import TagChooser from "select-kit/components/tag-chooser";

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

  <template>
    <section class="tag-info">
      {{#if this.tagInfo}}
        <div class="tag-name">
          {{#if this.editing}}
            <div class="edit-tag-wrapper">
              <TextField
                @id="edit-name"
                @value={{readonly this.tagInfo.name}}
                @maxlength={{this.siteSettings.max_tag_length}}
                @input={{withEventValue (fn (mut this.newTagName))}}
                @autofocus="true"
              />

              <Textarea
                id="edit-description"
                @value={{readonly this.tagInfo.descriptionWithNewLines}}
                placeholder={{i18n "tagging.description"}}
                maxlength={{1000}}
                {{on
                  "input"
                  (withEventValue (fn (mut this.newTagDescription)))
                }}
                autofocus="true"
              />

              <div class="edit-controls">
                {{#unless this.updateDisabled}}
                  <DButton
                    @action={{this.finishedEditing}}
                    @icon="check"
                    @ariaLabel="tagging.save"
                    class="btn-primary submit-edit"
                  />
                {{/unless}}
                <DButton
                  @action={{this.cancelEditing}}
                  @icon="xmark"
                  @ariaLabel="cancel"
                  class="btn-default cancel-edit"
                />
              </div>
            </div>
          {{else}}
            <div class="tag-name-wrapper">
              {{discourseTag this.tagInfo.name tagName="div"}}
              {{#if this.canAdminTag}}
                <a
                  href
                  {{on "click" this.edit}}
                  class="edit-tag"
                  title={{i18n "tagging.edit_tag"}}
                >{{icon "pencil"}}</a>
              {{/if}}
            </div>
            {{#if this.tagInfo.description}}
              <div class="tag-description-wrapper">
                <span>{{htmlSafe this.tagInfo.description}}</span>
              </div>
            {{/if}}
          {{/if}}
        </div>
        <div class="tag-associations">
          {{~#if this.tagInfo.tag_group_names}}
            {{this.tagGroupsInfo}}
          {{/if~}}
          {{~#if this.tagInfo.categories}}
            {{this.categoriesInfo}}
            <br />
            {{#each this.tagInfo.categories as |category|}}
              {{categoryLink category}}
            {{/each}}
          {{/if~}}
          {{~#if this.nothingToShow}}
            {{#if this.tagInfo.category_restricted}}
              {{i18n "tagging.category_restricted"}}
            {{else}}
              {{htmlSafe (i18n "tagging.default_info")}}
              {{#if this.canAdminTag}}
                {{htmlSafe (i18n "tagging.staff_info" basePath=(basePath))}}
              {{/if}}
            {{/if}}
          {{/if~}}
        </div>
        {{#if this.tagInfo.synonyms}}
          <div class="synonyms-list">
            <h3>{{i18n "tagging.synonyms"}}</h3>
            <div>{{htmlSafe
                (i18n
                  "tagging.synonyms_description" base_tag_name=this.tagInfo.name
                )
              }}</div>
            <div class="tag-list">
              {{#each this.tagInfo.synonyms as |tag|}}
                <div class="tag-box">
                  {{discourseTag tag.id pmOnly=tag.pmOnly tagName="div"}}
                  {{#if this.editSynonymsMode}}
                    <a
                      href
                      {{on "click" (fn this.unlinkSynonym tag)}}
                      class="unlink-synonym"
                    >
                      {{icon "link-slash" title="tagging.remove_synonym"}}
                    </a>
                    <a
                      href
                      {{on "click" (fn this.deleteSynonym tag)}}
                      class="delete-synonym"
                    >
                      {{icon "trash-can" title="tagging.delete_tag"}}
                    </a>
                  {{/if}}
                </div>
              {{/each}}
            </div>
          </div>
        {{/if}}
        {{#if this.editSynonymsMode}}
          <section class="add-synonyms field">
            <label for="add-synonyms">{{i18n
                "tagging.add_synonyms_label"
              }}</label>
            <div class="add-synonyms__controls">
              <TagChooser
                @id="add-synonyms"
                @tags={{this.newSynonyms}}
                @blockedTags={{array this.tagInfo.name}}
                @everyTag={{true}}
                @excludeSynonyms={{true}}
                @excludeHasSynonyms={{true}}
                @unlimitedTagCount={{true}}
                @allowCreate={{true}}
              />
              {{#if this.newSynonyms}}
                <DButton
                  @action={{this.addSynonyms}}
                  @disabled={{this.addSynonymsDisabled}}
                  @icon="check"
                  class="ok"
                />
              {{/if}}
            </div>
          </section>
        {{/if}}
        {{#if this.canAdminTag}}
          <PluginOutlet
            @name="tag-custom-settings"
            @outletArgs={{lazyHash tag=this.tagInfo}}
            @connectorTagName="section"
          />

          <div class="tag-actions">
            <DButton
              @action={{this.toggleEditControls}}
              @icon="gear"
              @label="tagging.edit_synonyms"
              id="edit-synonyms"
              class="btn-default"
            />
            {{#if this.canAdminTag}}
              <DButton
                @action={{this.deleteTag}}
                @icon="trash-can"
                @label="tagging.delete_tag"
                id="delete-tag"
                class="btn-danger delete-tag"
              />
            {{/if}}
          </div>
        {{/if}}
      {{/if}}
      {{#if this.loading}}
        <div>{{i18n "loading"}}</div>
      {{/if}}
    </section>
  </template>
}
