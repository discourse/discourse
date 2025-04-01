import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import { not } from "truth-helpers";
import icon from "discourse/helpers/d-icon";
import noop from "discourse/helpers/noop";

export default class FormTemplateFieldMultiSelect extends Component {
  @service composer;
  @service dialog;

  @tracked currentTags = [];
  @tracked previousTags;

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
      let composerTags = this.composer.model.tags || [];

      let selectedTag = composerTags.filter((tag) =>
        this.args.choices.includes(tag)
      );

      if (selectedTag.length > 1) {
        this.dialog.alert(
        `You can't select more tags from the ${this.args.tagGroup}. To avoid issues, use Form Template`
      );

        this.previousTags = this.currentTags;

        let oldTags = composerTags.filter((tag) => this.previousTags.includes(tag));

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
  handleInput(event) {
    let selectedValue = event.target.value.toLowerCase().replace(/\s+/g, "-");

    //Cook template
    this.args.onChange?.(selectedValue);

    if (this.args.tagGroup) {
      this.updateComposerTags(selectedValue);
    }
  }

  @action
  updateComposerTags(selectedValue) {
    let previousTags = this.previousTags || [];
    this.previousTags = [selectedValue];

    let composerTags = this.composer.model.tags;

    // Remove deselected tags and add new selections
    let updatedTags = [
      ...composerTags.filter((tag) => !previousTags.includes(tag)),
      selectedValue,
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
      return this.args.value === option;
    }
  }

  <template>
    <div
      class="control-group form-template-field"
      data-field-type="dropdown"
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
        class="form-template-field__dropdown"
        required={{if @validations.required "required" ""}}
        {{on "input" this.handleInput}}
      >
        {{#if @attributes.none_label}}
          <option
            class="form-template-field__dropdown-placeholder"
            value
            disabled={{if this.currentTags.length "false" "true"}}
            selected={{if (not this.currentTags.length) "selected" ""}}
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
