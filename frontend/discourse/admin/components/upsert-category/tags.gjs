import Component from "@glimmer/component";
import { array, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import concatClass from "discourse/helpers/concat-class";
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
  onTagGroupFieldChange(field, valueArray) {
    field.set(valueArray[0]);
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
        @format="max"
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
        @format="max"
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
        @format="max"
        @disabled={{this.disableAllowGlobalTags}}
        as |field|
      >
        <field.Checkbox />
      </@form.Field>

      <@form.Alert @type="info">
        {{i18n "category.tags_tab_description"}}
      </@form.Alert>

      <@form.Section @title={{i18n "category.required_tag_group.description"}}>
        <@form.Collection @name="required_tag_groups" as |collection index|>
          <@form.Row as |row|>
            <row.Col @size={{2}}>
              <collection.Field
                @name="min_count"
                @title={{i18n "category.required_tag_group.min_count"}}
                @validation="required"
                as |field|
              >
                <field.Input @type="number" min="1" />
              </collection.Field>
            </row.Col>

            <row.Col @size={{9}}>
              <collection.Field
                @name="name"
                @title={{i18n "category.required_tag_group.tag_group"}}
                @validation="required"
                as |field|
              >
                <field.Custom>
                  <TagGroupChooser
                    @tagGroups={{if field.value (array field.value) (array)}}
                    @onChange={{fn this.onTagGroupFieldChange field}}
                    @options={{hash
                      maximum=1
                      filterPlaceholder="category.required_tag_group.placeholder"
                    }}
                  />
                </field.Custom>
              </collection.Field>
            </row.Col>

            <row.Col @size={{1}}>
              <@form.Button
                class="btn-danger delete-required-tag-group"
                @icon="trash-can"
                @title="category.required_tag_group.delete"
                @action={{fn collection.remove index}}
              />
            </row.Col>
          </@form.Row>
        </@form.Collection>

        <@form.Button
          class="btn-default add-required-tag-group"
          @icon="plus"
          @label="category.required_tag_group.add"
          @action={{fn
            @form.addItemToCollection
            "required_tag_groups"
            (hash min_count=1)
          }}
        />
      </@form.Section>
    </@form.Section>
  </template>
}
