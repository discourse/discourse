import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";

export default class FormTemplateFieldMultiSelect extends Component {
  @service composer;

  @tracked previousTags;
  @tracked currentTags = [];

  constructor() {
    super(...arguments);
    this.syncWithComposerTags();
  }

  get formattedChoices() {
    if (this.args.tagChoices) {
      return this.args.choices.map((choice) => ({
        name: choice,
        display: this.args.tagChoices[choice]
          ? this.args.tagChoices[choice]
          : choice.replace(/-/g, " ").toUpperCase(),
      }));
    } else {
      return this.args.choices.map((choice) => ({
        name: choice,
        display: this.args.tagGroup
          ? choice.replace(/-/g, " ").toUpperCase()
          : choice,
      }));
    }
  }

  get filteredSelectedValues() {
    return this.currentTags.filter((tag) =>
      this.formattedChoices.some((choice) => choice.name === tag)
    );
  }

  @action
  syncWithComposerTags() {
    if (this.args.onChange) {
      this.currentTags = [...(this.composer.model.tags || [])];
      next(this, () => {
        this.args.onChange(this.currentTags);
      });
    }
  }

  @action
  handleSelectedValues(event) {
    let selectedValues = [];
    if (this.args.tagChoices) {
      let choiceMap = new Map(
        Object.entries(this.args.tagChoices).map(([key, value]) => [value, key])
      );

      selectedValues = Array.from(event.target.selectedOptions).map(
        (option) =>
          choiceMap.get(option.textContent.trim()) ||
          option.value.toLowerCase().replace(/\s+/g, "-")
      );
    } else {
      selectedValues = Array.from(event.target.selectedOptions).map((option) =>
        option.value.toLowerCase().replace(/\s+/g, "-")
      );
    }

    return selectedValues;
  }

  @action
  handleInput(event) {
    let selectedValues = this.handleSelectedValues(event);

    this.args.onChange?.([...selectedValues]);

    if (this.args.tagGroup) {
      this.updateComposerTags(selectedValues);
    }
  }

  @action
  updateComposerTags(selectedValues) {
    let previousTags = this.previousTags || [];
    this.previousTags = [...selectedValues];

    let composerTags = this.composer.model.tags;
    let updatedTags = [
      ...composerTags.filter((tag) => !previousTags.includes(tag)),
      ...selectedValues,
    ];

    this.currentTags = updatedTags;
    set(this.composer.model, "tags", [...updatedTags]);
  }

  @action
  isSelected(option) {
    if (this.args.tagGroup) {
      option = option.toLowerCase().replace(/\s+/g, "-");
      return this.filteredSelectedValues.includes(option);
    } else {
      return this.args.value?.includes(option);
    }
  }

  <template>
    <div
      data-field-type="multi-select"
      class="control-group form-template-field"
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
        multiple="multiple"
        class="form-template-field__multi-select"
        {{on "input" this.handleInput}}
      >
        {{#if @attributes.none_label}}
          <option
            class="form-template-field__multi-select-placeholder"
            value=""
            disabled
            hidden
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
