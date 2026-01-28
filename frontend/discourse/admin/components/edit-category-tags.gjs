import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { array, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import DButton from "discourse/components/d-button";
import withEventValue from "discourse/helpers/with-event-value";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import TagGroupChooser from "discourse/select-kit/components/tag-group-chooser";
import { i18n } from "discourse-i18n";

export default class EditCategoryTags extends Component {
  get category() {
    return this.args.category;
  }

  get form() {
    return this.args.form;
  }

  get transientData() {
    return this.args.transientData;
  }

  get minimumRequiredTags() {
    return (
      this.transientData?.minimum_required_tags ??
      this.category?.minimum_required_tags
    );
  }

  get allowedTags() {
    return (
      this.transientData?.allowed_tags ?? this.category?.allowed_tags ?? []
    );
  }

  get allowedTagGroups() {
    return (
      this.transientData?.allowed_tag_groups ??
      this.category?.allowed_tag_groups ??
      []
    );
  }

  get allowGlobalTags() {
    return (
      this.transientData?.allow_global_tags ?? this.category?.allow_global_tags
    );
  }

  get requiredTagGroups() {
    return (
      this.transientData?.required_tag_groups ??
      this.category?.required_tag_groups ??
      []
    );
  }

  get disableAllowGlobalTags() {
    const allowedTagsEmpty = !this.allowedTags || this.allowedTags.length === 0;
    const allowedTagGroupsEmpty =
      !this.allowedTagGroups || this.allowedTagGroups.length === 0;
    return allowedTagsEmpty && allowedTagGroupsEmpty;
  }

  get panelClass() {
    const isActive = this.args.selectedTab === "tags" ? "active" : "";
    return `edit-category-tab edit-category-tab-tags ${isActive}`;
  }

  @action
  onMinimumRequiredTagsChange(value) {
    this.form.set("minimum_required_tags", value);
  }

  @action
  onAllowedTagsChange(tags) {
    this.form.set("allowed_tags", tags);
  }

  @action
  onAllowedTagGroupsChange(tagGroups) {
    this.form.set("allowed_tag_groups", tagGroups);
  }

  @action
  onAllowGlobalTagsChange(event) {
    this.form.set("allow_global_tags", event.target.checked);
  }

  @action
  onTagGroupChange(rtgIndex, valueArray) {
    const newRequiredTagGroups = this.requiredTagGroups.map((rtg, idx) =>
      idx === rtgIndex ? { ...rtg, name: valueArray[0] } : rtg
    );
    this.form.set("required_tag_groups", newRequiredTagGroups);
  }

  @action
  onMinCountChange(rtgIndex, value) {
    const newRequiredTagGroups = this.requiredTagGroups.map((rtg, idx) =>
      idx === rtgIndex ? { ...rtg, min_count: value } : rtg
    );
    this.form.set("required_tag_groups", newRequiredTagGroups);
  }

  @action
  addRequiredTagGroup() {
    const newRequiredTagGroups = [...this.requiredTagGroups, { min_count: 1 }];
    this.form.set("required_tag_groups", newRequiredTagGroups);
  }

  @action
  deleteRequiredTagGroup(rtgIndex) {
    const newRequiredTagGroups = this.requiredTagGroups.filter(
      (_, idx) => idx !== rtgIndex
    );
    this.form.set("required_tag_groups", newRequiredTagGroups);
  }

  <template>
    <div class={{this.panelClass}}>
      <section class="field minimum-required-tags">
        <label for="category-minimum-tags">
          {{i18n "category.minimum_required_tags"}}
        </label>
        <input
          type="number"
          min="0"
          id="category-minimum-tags"
          value={{this.minimumRequiredTags}}
          {{on "input" (withEventValue this.onMinimumRequiredTagsChange)}}
        />
      </section>
      <section class="field allowed-tags">
        <label>
          {{#if this.category.id}}
            {{i18n
              "category.tags_allowed_tags"
              categoryName=this.category.name
            }}
          {{else}}
            {{i18n "category.tags_allowed_tags_new_category"}}
          {{/if}}
        </label>
        <TagChooser
          @id="category-allowed-tags"
          @tags={{this.allowedTags}}
          @everyTag={{true}}
          @excludeSynonyms={{true}}
          @unlimitedTagCount={{true}}
          @onChange={{this.onAllowedTagsChange}}
          @options={{hash filterPlaceholder="category.tags_placeholder"}}
        />
      </section>

      <section class="field allowed-tag-groups">
        <label>
          {{#if this.category.id}}
            {{i18n
              "category.tags_allowed_tag_groups"
              categoryName=this.category.name
            }}
          {{else}}
            {{i18n "category.tags_allowed_tag_groups_new_category"}}
          {{/if}}
        </label>
        <TagGroupChooser
          @id="category-allowed-tag-groups"
          @tagGroups={{this.allowedTagGroups}}
          @onChange={{this.onAllowedTagGroupsChange}}
        />
        <LinkTo @route="tagGroups" class="manage-tag-groups">{{i18n
            "category.manage_tag_groups_link"
          }}</LinkTo>
      </section>

      <section class="field allow-global-tags">
        <label>
          <Input
            @type="checkbox"
            @checked={{this.allowGlobalTags}}
            id="allow_global_tags"
            disabled={{this.disableAllowGlobalTags}}
            {{on "change" this.onAllowGlobalTagsChange}}
          />
          {{i18n "category.allow_global_tags_label"}}
        </label>
      </section>

      <section class="field tags-tab-description">
        {{i18n "category.tags_tab_description"}}
      </section>

      <section class="field required-tag-group-description">
        {{i18n "category.required_tag_group.description"}}
      </section>

      <section class="field with-items">
        <section class="field-item required-tag-groups">
          {{#each this.requiredTagGroups as |rtg index|}}
            <div class="required-tag-group-row">
              <input
                type="number"
                min="1"
                value={{rtg.min_count}}
                {{on "input" (withEventValue (fn this.onMinCountChange index))}}
              />
              <TagGroupChooser
                @tagGroups={{if rtg.name (array rtg.name) (array)}}
                @onChange={{fn this.onTagGroupChange index}}
                @options={{hash
                  maximum=1
                  filterPlaceholder="category.required_tag_group.placeholder"
                }}
              />
              <DButton
                @label="category.required_tag_group.delete"
                @action={{fn this.deleteRequiredTagGroup index}}
                @icon="trash-can"
                class="delete-required-tag-group"
              />
            </div>
          {{/each}}
          <DButton
            @label="category.required_tag_group.add"
            @action={{this.addRequiredTagGroup}}
            @icon="plus"
            class="btn-default add-required-tag-group"
          />
        </section>
      </section>
    </div>
  </template>
}
