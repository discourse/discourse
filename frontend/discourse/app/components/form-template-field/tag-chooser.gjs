import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class TagChooserField extends Component {
  @service composer;
  @service dialog;

  get formattedChoices() {
    return this.args.choices.map((tag) => ({
      id: tag.id,
      name: tag.name,
      display: this.args.attributes.tag_choices[tag.name]
        ? this.args.attributes.tag_choices[tag.name]
        : tag.name.replace(/-/g, " ").toUpperCase(),
    }));
  }

  _tagId(tag) {
    return typeof tag === "object" ? tag.id : null;
  }

  get filteredSelectedValues() {
    return this.tags.filter((tag) =>
      this.formattedChoices.some((choice) => choice.id === this._tagId(tag))
    );
  }

  get selectedTags() {
    return this.tags.filter((tag) =>
      this.args.choices.some((choice) => choice.id === this._tagId(tag))
    );
  }

  @action
  dropdownSyncWithComposerTags() {
    if (!this.args.onChange) {
      return;
    }

    if (this.selectedTags.length > 1) {
      // the composer mini tag chooser can allow multiple tags
      // so if the user chooses multiple tags directly in this component
      // we will display an error to prevent it
      this.dialog.alert(
        i18n("admin.form_templates.errors.multiple_tags_not_allowed", {
          tag_name: this.args.attributes.tag_group,
        })
      );

      const selectedTagIds = this.selectedTags.map((t) => this._tagId(t));
      const filteredTags = [
        ...this.tags.filter(
          (tag) => !selectedTagIds.includes(this._tagId(tag))
        ),
      ];

      // the next is needed because we already updated the tags in the same runloop
      // when the user selected a tag in the composer directly
      next(() => {
        set(this.composer.model, "tags", filteredTags);
        this.args.onChange([]);
      });
    } else {
      this.args.onChange(this.tags);
    }
  }

  get tags() {
    return this.composer.get("model.tags") || [];
  }

  @action
  syncWithComposerTags() {
    if (this.args.attributes.multiple) {
      this.args.onChange?.(this.tags);
    } else {
      this.dropdownSyncWithComposerTags();
    }
  }

  @action
  handleSelectedTagIds(event) {
    return Array.from(event.target.selectedOptions)
      .map((option) => parseInt(option.value, 10))
      .filter((id) => !isNaN(id));
  }

  @action
  handleInput(event) {
    const selectedTagIds = this.handleSelectedTagIds(event);
    const validTagIds = this.formattedChoices.map((choice) => choice.id);
    const filteredTagIds = selectedTagIds.filter((tagId) =>
      validTagIds.includes(tagId)
    );
    const existingSelectedTagIds = this.selectedTags.map((t) => this._tagId(t));

    const selectedTags = filteredTagIds.map((tagId) =>
      this.formattedChoices.find((choice) => choice.id === tagId)
    );

    set(
      this.composer.model,
      "tags",
      uniqueItemsFromArray([
        ...this.tags.filter(
          (tag) => !existingSelectedTagIds.includes(this._tagId(tag))
        ),
        ...selectedTags,
      ])
    );
  }

  @action
  isSelected(tagId) {
    return this.filteredSelectedValues.some(
      (tag) => this._tagId(tag) === tagId
    );
  }

  <template>
    <div
      data-field-type="multi-select"
      class="control-group form-template-field"
      {{didInsert this.syncWithComposerTags}}
      {{! not ideal but we would need a lot of re-architecturing to make the form dynamic }}
      {{didUpdate this.syncWithComposerTags this.composer.model.tags}}
    >
      {{#if @attributes.label}}
        <label class="form-template-field__label">
          {{@attributes.label}}
          {{#if @validations.required}}
            {{icon "asterisk" class="form-template-field__required-indicator"}}
          {{/if}}
        </label>
      {{/if}}

      {{#if @attributes.description}}
        <span class="form-template-field__description">
          {{htmlSafe @attributes.description}}
        </span>
      {{/if}}

      <select
        name={{@id}}
        required={{if @validations.required "required" ""}}
        multiple={{@attributes.multiple}}
        class="form-template-field__multi-select"
        {{on "input" this.handleInput}}
      >
        {{#if @attributes.none_label}}
          <option
            class="form-template-field__multi-select-placeholder"
            value=""
            disabled={{not this.selectedTags.length}}
            selected={{if this.selectedTags.length "" "selected"}}
          >{{@attributes.none_label}}</option>
        {{/if}}
        {{#each this.formattedChoices as |choice|}}
          <option
            value={{choice.id}}
            selected={{this.isSelected choice.id}}
          >{{choice.display}}</option>
        {{/each}}
      </select>
    </div>
  </template>
}
