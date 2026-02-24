import Component from "@glimmer/component";
import { array, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import withEventValue from "discourse/helpers/with-event-value";
import TagGroupChooser from "discourse/select-kit/components/tag-group-chooser";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class UpsertCategoryTags extends Component {
  get allowedTags() {
    return this.args.transientData?.allowed_tags;
  }

  get allowedTagGroups() {
    return this.args.transientData?.allowed_tag_groups;
  }

  get requiredTagGroups() {
    return this.args.transientData?.required_tag_groups ?? [];
  }

  get disableAllowGlobalTags() {
    const allowedTagsEmpty = !this.allowedTags || this.allowedTags.length === 0;
    const allowedTagGroupsEmpty =
      !this.allowedTagGroups || this.allowedTagGroups.length === 0;
    return allowedTagsEmpty && allowedTagGroupsEmpty;
  }

  @action
  onAllowedTagGroupsChange(tagGroups) {
    this.args.form.set("allowed_tag_groups", tagGroups);
  }

  @action
  onTagGroupChange(rtgIndex, valueArray) {
    // A little strange, but we're using a multi-select component
    // to select a single tag group. This action takes the array
    // and extracts the first value in it.
    const newRequiredTagGroups = this.requiredTagGroups.map((rtg, idx) =>
      idx === rtgIndex ? { ...rtg, name: valueArray[0] } : rtg
    );
    this.args.form.set("required_tag_groups", newRequiredTagGroups);
  }

  @action
  onMinCountChange(rtgIndex, value) {
    const newRequiredTagGroups = this.requiredTagGroups.map((rtg, idx) =>
      idx === rtgIndex ? { ...rtg, min_count: value } : rtg
    );
    this.args.form.set("required_tag_groups", newRequiredTagGroups);
  }

  @action
  addRequiredTagGroup() {
    const newRequiredTagGroups = [...this.requiredTagGroups, { min_count: 1 }];
    this.args.form.set("required_tag_groups", newRequiredTagGroups);
  }

  @action
  deleteRequiredTagGroup(rtgIndex) {
    const newRequiredTagGroups = this.requiredTagGroups.filter(
      (_, idx) => idx !== rtgIndex
    );
    this.args.form.set("required_tag_groups", newRequiredTagGroups);
  }

  <template>
    <@form.Section
      class={{concatClass
        "edit-category-tab"
        "edit-category-tab-tags"
        (if (eq @selectedTab "tags") "active")
      }}
    >
      <@form.Field
        @name="minimum_required_tags"
        @title={{i18n "category.minimum_required_tags"}}
        @format="large"
        as |field|
      >
        <field.Input type="number" min="0" id="category-minimum-tags" />
      </@form.Field>

      <@form.Field
        @name="allowed_tags"
        @title={{if
          @category.id
          (i18n "category.tags_allowed_tags" categoryName=@category.name)
          (i18n "category.tags_allowed_tags_new_category")
        }}
        @format="large"
        as |field|
      >
        <field.TagChooser
          @showAllTags={{true}}
          @excludeSynonyms={{true}}
          @unlimited={{true}}
          @placeholder="category.tags_placeholder"
        />
      </@form.Field>

      <@form.Container
        @direction="column"
        @optional={{true}}
        @title={{if
          @category.id
          (i18n "category.tags_allowed_tag_groups" categoryName=@category.name)
          (i18n "category.tags_allowed_tag_groups_new_category")
        }}
      >
        <TagGroupChooser
          @id="category-allowed-tag-groups"
          @tagGroups={{this.allowedTagGroups}}
          @onChange={{this.onAllowedTagGroupsChange}}
        />
        <LinkTo @route="tagGroups" class="manage-tag-groups">
          {{i18n "category.manage_tag_groups_link"}}
        </LinkTo>
      </@form.Container>

      <@form.Field
        @name="allow_global_tags"
        @title={{i18n "category.allow_global_tags_label"}}
        @format="large"
        @disabled={{this.disableAllowGlobalTags}}
        as |field|
      >
        <field.Checkbox />
      </@form.Field>

      <@form.Alert @type="info">
        {{i18n "category.tags_tab_description"}}
      </@form.Alert>

      <@form.Section @title={{i18n "category.required_tag_group.description"}}>
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
      </@form.Section>
    </@form.Section>
  </template>
}
