import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { not } from "truth-helpers";
import icon from "discourse/helpers/d-icon";

export default class TagChooserField extends Component {
  @service composer;
  @service dialog;

  @tracked previousTags;
  @tracked currentTags = [];

  _formattedChoices;

  constructor() {
    super(...arguments);
    this.syncWithComposerTags();
  }

  get formattedChoices() {
    if (!this._formattedChoices) {
      this._formattedChoices = this.args.choices.map((choice) => ({
        name: choice,
        display: this.args.tagChoices[choice]
          ? this.args.tagChoices[choice]
          : choice.replace(/-/g, " ").toUpperCase(),
      }));
    }
    return this._formattedChoices;
  }

  get filteredSelectedValues() {
    return this.currentTags.filter((tag) =>
      this.formattedChoices.some((choice) => choice.name === tag)
    );
  }

  @action
  dropdownSyncWithComposerTags() {
    if (this.args.onChange) {
      let composerTags = this.composer.model.tags || [];

      let selectedTag = composerTags.filter((tag) =>
        this.args.choices.includes(tag)
      );

      if (selectedTag.length > 1) {
        this.dialog.alert(
          `You can't select more tags from the ${this.args.tagGroup}. To avoid issues, use Form Template`
        );
        this.previousTags = this.currentTags;

        let oldTags = composerTags.filter((tag) =>
          this.previousTags.includes(tag)
        );

        next(this, () => {
          set(this, "currentTags", oldTags);
          next(this, () => {
            set(this.composer.model, "tags", oldTags);
            this.args.onChange(oldTags);
          });
        });
      } else {
        this.previousTags = this.currentTags;
        next(this, () => {
          set(this, "currentTags", selectedTag);
          next(this, () => {
            this.args.onChange(this.currentTags);
          });
        });
      }
    }
  }

  @action
  syncWithComposerTags() {
    if (this.args.attributes.multiple) {
      this.currentTags = [...(this.composer.model.tags || [])];

      next(this, () => {
        this.args.onChange(this.currentTags);
      });
    } else {
      this.dropdownSyncWithComposerTags();
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
    this.updateComposerTags(selectedValues);
  }

  @action
  updateComposerTags(selectedValues) {
    let validChoices = this.formattedChoices.map((choice) => choice.name);
    let previousTags = (this.previousTags || []).filter((tag) =>
      validChoices.includes(tag)
    );

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
    option = option.toLowerCase().replace(/\s+/g, "-");
    return this.filteredSelectedValues.includes(option);
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
        multiple={{@attributes.multiple}}
        class="form-template-field__multi-select"
        {{on "input" this.handleInput}}
      >
        {{#if @attributes.none_label}}
          <option
            class="form-template-field__multi-select-placeholder"
            value=""
            disabled={{if this.currentTags.length "false" "true"}}
            selected={{if this.currentTags.length "" "selected"}}
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
