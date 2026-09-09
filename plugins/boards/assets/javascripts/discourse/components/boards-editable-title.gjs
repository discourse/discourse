import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";

class BoardsEditableTitleUi extends Component {
  @tracked isEditing = isEmpty(this.args.field.value);

  get hasValue() {
    return !isEmpty(this.args.field.value);
  }

  get displayValue() {
    return this.args.field.value || this.args.placeholder;
  }

  @action
  startEditing() {
    if (this.args.field.disabled) {
      return;
    }
    this.isEditing = true;
  }

  @action
  onInput(event) {
    this.args.field.set(event.target.value);
  }

  @action
  finishEditing() {
    const value = this.args.field.value?.trim() ?? "";
    this.args.field.set(value);
    this.isEditing = false;
  }

  @action
  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.target.blur();
    } else if (event.key === "Escape") {
      this.isEditing = false;
    }
  }

  <template>
    {{#if this.isEditing}}
      <input
        type="text"
        value={{@field.value}}
        placeholder={{@placeholder}}
        class="discourse-boards-editable-title__input"
        id={{@field.id}}
        name={{@field.name}}
        disabled={{@field.disabled}}
        aria-invalid={{if @field.error "true"}}
        aria-describedby={{if @field.error @field.errorId}}
        {{dAutoFocus selectText=true}}
        {{on "input" this.onInput}}
        {{on "blur" this.finishEditing}}
        {{on "keydown" this.handleKeydown}}
      />
    {{else}}
      <DButton
        class={{dConcatClass
          "btn-flat discourse-boards-editable-title__text"
          (unless this.hasValue "--empty")
        }}
        @action={{this.startEditing}}
      >{{dReplaceEmoji this.displayValue}}</DButton>
    {{/if}}
    {{#if @showClose}}
      <DButton
        @action={{@onClose}}
        @icon="xmark"
        @ariaLabel="modal.close"
        @title="modal.close"
        class="btn-flat discourse-boards-editable-title__close"
      />
    {{/if}}
  </template>
}

export default class BoardsEditableTitle extends Component {
  get validation() {
    if (this.args.validate) {
      return null;
    }

    return this.args.validation || "required:trim";
  }

  <template>
    <div class="discourse-boards-editable-title">
      <@form.Field
        @name={{@name}}
        @title={{@title}}
        @type="custom"
        @validation={{this.validation}}
        @showTitle={{false}}
        @disabled={{@disabled}}
        @validate={{@validate}}
        @format="full"
        as |field|
      >
        <field.Control>
          <BoardsEditableTitleUi
            @field={{field}}
            @placeholder={{@placeholder}}
            @showClose={{@showClose}}
            @onClose={{@onClose}}
          />
        </field.Control>
      </@form.Field>
    </div>
  </template>
}
