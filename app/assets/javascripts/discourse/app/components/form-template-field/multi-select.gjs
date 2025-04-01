import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import noop from "discourse/helpers/noop";

export default class FormTemplateFieldMultiSelect extends Component {
  @service composer;

  @tracked previousTags;
  @tracked currentTags = [];

  constructor() {
    super(...arguments);
    this.syncWithComposerTags();
  }

  get formattedChoices() {
    return this.args.choices.map((choice) =>
      this.args.tagGroup ? choice.replace(/-/g, " ").toUpperCase() : choice
    );
  }

  get filteredSelectedValues() {
    return this.currentTags.filter((tag) => this.args.choices.includes(tag));
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
  handleInput(event) {
    let selectedValues = Array.from(event.target.selectedOptions).map(
      (option) => option.value.toLowerCase().replace(/\s+/g, "-")
    );

    //Cook template
    this.args.onChange?.([...selectedValues]);

    if (this.args.tagGroup) {
      this.updateComposerTags(selectedValues);
    }
  }

  @action
  updateComposerTags(selectedValues) {
    debugger;
    let previousTags = this.previousTags || [];
    this.previousTags = [...selectedValues];

    let composerTags = this.composer.model.tags;

    // Remove deselected tags and add new selections
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
            value={{choice}}
            selected={{this.isSelected choice}}
          >{{choice}}</option>
        {{/each}}
      </select>
    </div>
  </template>
}
