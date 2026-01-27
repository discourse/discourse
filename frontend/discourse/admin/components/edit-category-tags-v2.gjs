import { array, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import { and, empty } from "@ember/object/computed";
import { LinkTo } from "@ember/routing";
import { buildCategoryPanel } from "discourse/admin/components/edit-category-panel";
import DButton from "discourse/components/d-button";
import withEventValue from "discourse/helpers/with-event-value";
import { removeValueFromArray } from "discourse/lib/array-tools";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import TagGroupChooser from "discourse/select-kit/components/tag-group-chooser";
import { i18n } from "discourse-i18n";

export default class EditCategoryTagsV2 extends buildCategoryPanel("tags") {
  @empty("category.allowed_tags") allowedTagsEmpty;
  @empty("category.allowed_tag_groups") allowedTagGroupsEmpty;
  @and("allowedTagsEmpty", "allowedTagGroupsEmpty") disableAllowGlobalTags;

  @action
  onTagGroupChange(rtg, valueArray) {
    // A little strange, but we're using a multi-select component
    // to select a single tag group. This action takes the array
    // and extracts the first value in it.
    set(rtg, "name", valueArray[0]);
  }

  @action
  addRequiredTagGroup() {
    this.category.required_tag_groups.push({
      min_count: 1,
    });
  }

  @action
  deleteRequiredTagGroup(rtg) {
    removeValueFromArray(this.category.required_tag_groups, rtg);
  }

  <template>
    <@form.Field
      @name="minimum_required_tags"
      @title={{i18n "category.minimum_required_tags"}}
      @format="large"
      as |field|
    >
      <field.Input type="number" min="0" id="category-minimum-tags" />
    </@form.Field>

    <@form.Container
      @title={{if
        this.category.id
        (i18n "category.tags_allowed_tags" categoryName=this.category.name)
        (i18n "category.tags_allowed_tags_new_category")
      }}
    >
      <TagChooser
        @id="category-allowed-tags"
        @tags={{this.category.allowed_tags}}
        @everyTag={{true}}
        @excludeSynonyms={{true}}
        @unlimitedTagCount={{true}}
        @onChange={{fn (mut this.category.allowed_tags)}}
        @options={{hash filterPlaceholder="category.tags_placeholder"}}
      />
    </@form.Container>

    <@form.Container
      @title={{if
        this.category.id
        (i18n
          "category.tags_allowed_tag_groups" categoryName=this.category.name
        )
        (i18n "category.tags_allowed_tag_groups_new_category")
      }}
    >
      <TagGroupChooser
        @id="category-allowed-tag-groups"
        @tagGroups={{this.category.allowed_tag_groups}}
        @onChange={{fn (mut this.category.allowed_tag_groups)}}
      />
      <LinkTo @route="tagGroups" class="manage-tag-groups">{{i18n
          "category.manage_tag_groups_link"
        }}</LinkTo>
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
      {{#each this.category.required_tag_groups as |rtg|}}
        <div class="required-tag-group-row">
          <input
            type="number"
            min="1"
            value={{rtg.min_count}}
            {{on "input" (withEventValue (fn (mut rtg.min_count)))}}
          />
          <TagGroupChooser
            @tagGroups={{if rtg.name (array rtg.name) (array)}}
            @onChange={{fn this.onTagGroupChange rtg}}
            @options={{hash
              maximum=1
              filterPlaceholder="category.required_tag_group.placeholder"
            }}
          />
          <DButton
            @label="category.required_tag_group.delete"
            @action={{fn this.deleteRequiredTagGroup rtg}}
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
  </template>
}
