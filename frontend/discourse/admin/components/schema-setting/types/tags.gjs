import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FieldInputDescription from "discourse/admin/components/schema-setting/field-input-description";
import SchemaSettingTypeModels from "discourse/admin/components/schema-setting/types/models";
import { storedName } from "discourse/lib/tag-source";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";

export default class SchemaSettingTypeTags extends SchemaSettingTypeModels {
  @service siteSettings;

  @tracked
  value = this.args.value?.map((tag) => {
    if (this.args.sendTagIds && typeof tag === "number") {
      return this.args.tagRecords.get(tag) || { id: tag, name: String(tag) };
    }
    return tag;
  });

  type = "tags";

  get tagChooserOption() {
    return {
      allowAny: false,
      maximum: this.max,
    };
  }

  onChange(tags) {
    if (!this.args.sendTagIds) {
      return tags.map((tag) => tag.name);
    }

    return tags.map((tag) => {
      if (typeof tag.id === "number") {
        this.args.tagRecords.set(tag.id, tag);
      }
      return tag.id;
    });
  }

  @action
  onSelectInput(tags) {
    this.value = tags;
    this.args.onChange(tags.map((tag) => this.#submitted(tag)));
  }

  /** Name-only tags carry no id, so they keep being submitted by name. */
  #submitted(tag) {
    if (this.args.sendTagIds && typeof tag.id === "number") {
      this.args.tagRecords.set(tag.id, tag);
      return tag.id;
    }
    return storedName(tag);
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup) }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelectTag
        class={{if this.validationErrorMessage "--invalid"}}
        @allowCreate={{false}}
        @ignoreRestrictions={{@spec.every_tag}}
        @maximum={{this.max}}
        @multiple={{true}}
        @onChange={{this.onSelectInput}}
        @texts={{hash ariaLabel=@label}}
        @value={{this.value}}
      />
    {{else}}
      {{! TODO (select-kit-replacement-cleanup) }}
      <TagChooser
        class={{if this.validationErrorMessage "--invalid"}}
        @everyTag={{@spec.every_tag}}
        @onChange={{this.onInput}}
        @options={{this.tagChooserOption}}
        @tags={{this.value}}
      />
    {{/if}}

    <div class="schema-field__input-supporting-text">
      {{#if (and @description (not this.validationErrorMessage))}}
        <FieldInputDescription @description={{@description}} />
      {{/if}}

      {{#if this.validationErrorMessage}}
        <div class="schema-field__input-error">
          {{this.validationErrorMessage}}
        </div>
      {{/if}}
    </div>
  </template>
}
