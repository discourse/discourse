import { Input } from "@ember/component";
import { array, fn, hash } from "@ember/helper";
import { action, set } from "@ember/object";
import { and, empty } from "@ember/object/computed";
import { LinkTo } from "@ember/routing";
import DButton from "discourse/components/d-button";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import TextField from "discourse/components/text-field";
import { i18n } from "discourse-i18n";
import TagChooser from "select-kit/components/tag-chooser";
import TagGroupChooser from "select-kit/components/tag-group-chooser";

export default class EditCategoryTags extends buildCategoryPanel("tags") {
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
    this.category.required_tag_groups.pushObject({
      min_count: 1,
    });
  }

  @action
  deleteRequiredTagGroup(rtg) {
    this.category.required_tag_groups.removeObject(rtg);
  }

  <template>
    <section class="field minimum-required-tags">
      <label for="category-minimum-tags">
        {{i18n "category.minimum_required_tags"}}
      </label>
      <TextField
        @value={{this.category.minimum_required_tags}}
        @id="category-minimum-tags"
        @type="number"
        @min="0"
      />
    </section>
    <section class="field allowed-tags">
      <label>{{i18n "category.tags_allowed_tags"}}</label>
      <TagChooser
        @id="category-allowed-tags"
        @tags={{this.category.allowed_tags}}
        @everyTag={{true}}
        @excludeSynonyms={{true}}
        @unlimitedTagCount={{true}}
        @onChange={{fn (mut this.category.allowed_tags)}}
        @options={{hash filterPlaceholder="category.tags_placeholder"}}
      />
    </section>

    <section class="field allowed-tag-groups">
      <label>{{i18n "category.tags_allowed_tag_groups"}}</label>
      <TagGroupChooser
        @id="category-allowed-tag-groups"
        @tagGroups={{this.category.allowed_tag_groups}}
        @onChange={{fn (mut this.category.allowed_tag_groups)}}
      />
      <LinkTo @route="tagGroups" class="manage-tag-groups">{{i18n
          "category.manage_tag_groups_link"
        }}</LinkTo>
    </section>

    <section class="field allow-global-tags">
      <label>
        <Input
          @type="checkbox"
          @checked={{this.category.allow_global_tags}}
          id="allow_global_tags"
          disabled={{this.disableAllowGlobalTags}}
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
        {{#each this.category.required_tag_groups as |rtg|}}
          <div class="required-tag-group-row">
            <TextField @value={{rtg.min_count}} @type="number" @min="1" />
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
      </section>
    </section>
  </template>
}
