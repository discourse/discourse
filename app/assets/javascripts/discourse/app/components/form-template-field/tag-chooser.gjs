import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { not } from "truth-helpers";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class TagChooserField extends Component {
  @service composer;
  @service dialog;

  get formattedChoices() {
    return this.args.choices.map((choice) => ({
      name: choice,
      display: this.args.attributes.tag_choices[choice]
        ? this.args.attributes.tag_choices[choice]
        : choice.replace(/-/g, " ").toUpperCase(),
    }));
  }

  get filteredSelectedValues() {
    return this.tags.filter((tag) =>
      this.formattedChoices.some((choice) => choice.name === tag)
    );
  }

  get selectedTags() {
    return this.tags.filter((tag) => this.args.choices.includes(tag));
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

      const selectedTags = [
        ...this.tags.filter((tag) => !this.selectedTags.includes(tag)),
      ];

      // the next is needed because we already updated the tags in the same runloop
      // when the user selected a tag in the composer directly
      next(() => {
        set(this.composer.model, "tags", selectedTags);
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
  handleSelectedValues(event) {
    const getFallbackValue = (optionValue) =>
      optionValue.toLowerCase().replace(/\s+/g, "-");
    let choiceMap = null;
    const tagChoices = this.args.attributes.tag_choices;

    if (tagChoices) {
      choiceMap = new Map(
        Object.entries(tagChoices).map(([key, value]) => [value, key])
      );
    }

    const selectedValues = Array.from(event.target.selectedOptions).map(
      (option) => {
        const mappedValue = choiceMap?.get(option.textContent.trim());
        return mappedValue ?? getFallbackValue(option.value);
      }
    );

    return selectedValues;
  }

  @action
  handleInput(event) {
    const selectedValues = this.handleSelectedValues(event);
    const validChoices = this.formattedChoices.map((choice) => choice.name);
    const selectedTags = selectedValues.filter((tag) =>
      validChoices.includes(tag)
    );

    set(
      this.composer.model,
      "tags",
      [
        ...this.tags.filter((tag) => !this.selectedTags.includes(tag)),
        ...selectedTags,
      ].uniq()
    );
  }

  @action
  isSelected(option) {
    option = option.toLowerCase().replace(/\s+/g, "-");
    return this.filteredSelectedValues.includes(option);
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
            value={{choice.display}}
            selected={{this.isSelected choice.name}}
          >{{choice.display}}</option>
        {{/each}}
      </select>
    </div>
  </template>
}
