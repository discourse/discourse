import Component from "@glimmer/component";
import { array, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import TagGroupChooser from "discourse/select-kit/components/tag-group-chooser";
import DSelectTagGroup from "discourse/ui-kit/select/recipes/tags/d-select-tag-group";
import { i18n } from "discourse-i18n";

export default class UpsertCategoryTags extends Component {
  @service siteSettings;

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

  @action
  onSingleTagGroupFieldChange(field, value) {
    field.set(value ?? undefined);
  }

  <template>
    <@form.Field
      @name="minimum_required_tags"
      @title={{i18n "category.minimum_required_tags"}}
      @type="input-number"
      as |field|
    >
      <field.Control id="category-minimum-tags" min="0" />
    </@form.Field>

    <@form.Field
      @format="max"
      @name="allowed_tags"
      @title={{if
        @category.id
        (i18n "category.tags_allowed_tags" categoryName=@category.name)
        (i18n "category.tags_allowed_tags_new_category")
      }}
      @type="tag-chooser"
      as |field|
    >
      <field.Control
        @excludeSynonyms={{true}}
        @placeholder="category.tags_placeholder"
        @showAllTags={{true}}
        @unlimited={{true}}
      />
    </@form.Field>

    <@form.Container
      @direction="column"
      @format="full"
      @optional={{true}}
      @title={{if
        @category.id
        (i18n "category.tags_allowed_tag_groups" categoryName=@category.name)
        (i18n "category.tags_allowed_tag_groups_new_category")
      }}
    >
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectTagGroup
          @id="category-allowed-tag-groups"
          @onChange={{this.onAllowedTagGroupsChange}}
          @value={{this.allowedTagGroups}}
        />
      {{else}}
        <TagGroupChooser
          @id="category-allowed-tag-groups"
          @onChange={{this.onAllowedTagGroupsChange}}
          @tagGroups={{this.allowedTagGroups}}
        />
      {{/if}}
      <LinkTo class="manage-tag-groups" @route="tagGroups">
        {{i18n "category.manage_tag_groups_link"}}
      </LinkTo>
    </@form.Container>

    <@form.Field
      @disabled={{this.disableAllowGlobalTags}}
      @format="max"
      @name="allow_global_tags"
      @title={{i18n "category.allow_global_tags_label"}}
      @type="checkbox"
      as |field|
    >
      <field.Control />
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
              @type="input-number"
              @validation="required"
              as |field|
            >
              <field.Control min="1" />
            </collection.Field>
          </row.Col>

          <row.Col @size={{9}}>
            <collection.Field
              @name="name"
              @title={{i18n "category.required_tag_group.tag_group"}}
              @type="custom"
              @validation="required"
              as |field|
            >
              <field.Control>
                {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
                {{#if this.siteSettings.enable_new_select_controls}}
                  <DSelectTagGroup
                    @disabled={{field.disabled}}
                    @multiple={{false}}
                    @onChange={{fn this.onSingleTagGroupFieldChange field}}
                    @placeholder={{i18n
                      "category.required_tag_group.placeholder"
                    }}
                    @value={{field.value}}
                  />
                {{else}}
                  <TagGroupChooser
                    @onChange={{fn this.onTagGroupFieldChange field}}
                    @options={{hash
                      maximum=1
                      filterPlaceholder="category.required_tag_group.placeholder"
                    }}
                    @tagGroups={{if field.value (array field.value) (array)}}
                  />
                {{/if}}
              </field.Control>
            </collection.Field>
          </row.Col>

          <row.Col @size={{1}}>
            <@form.Button
              class="btn-danger delete-required-tag-group"
              @action={{fn collection.remove index}}
              @icon="trash-can"
              @title="category.required_tag_group.delete"
            />
          </row.Col>
        </@form.Row>
      </@form.Collection>

      <@form.Button
        class="btn-default add-required-tag-group"
        @action={{fn
          @form.addItemToCollection
          "required_tag_groups"
          (hash min_count=1)
        }}
        @icon="plus"
        @label="category.required_tag_group.add"
      />
    </@form.Section>
  </template>
}
