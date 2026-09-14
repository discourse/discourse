import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";

class BoardsEditableTitleUi extends Component {
  @tracked isEditing = isEmpty(this.args.field.value);

  get hasValue() {
    return !isEmpty(this.args.field.value);
  }

  get displayText() {
    return trustHTML(
      emojiUnescape(
        escapeExpression(this.args.field.value || this.args.placeholder)
      )
    );
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
        aria-describedby={{if @field.error @field.errorId}}
        aria-invalid={{if @field.error "true"}}
        class="discourse-boards-editable-title__input"
        disabled={{@field.disabled}}
        id={{@field.id}}
        name={{@field.name}}
        placeholder={{@placeholder}}
        type="text"
        value={{@field.value}}
        {{dAutoFocus selectText=true}}
        {{on "input" this.onInput}}
        {{on "blur" this.finishEditing}}
        {{on "keydown" this.handleKeydown}}
      />
    {{else}}
      {{! eslint-disable ember/template-no-invalid-interactive }}
      <div
        class={{dConcatClass
          "discourse-boards-editable-title__text"
          (unless this.hasValue "--empty")
        }}
        {{on "click" this.startEditing}}
      >{{this.displayText}}</div>
    {{/if}}
    {{#if @showClose}}
      <DButton
        class="btn-flat discourse-boards-editable-title__close"
        @action={{@onClose}}
        @ariaLabel="modal.close"
        @icon="xmark"
        @title="modal.close"
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
        @disabled={{@disabled}}
        @format="full"
        @name={{@name}}
        @showTitle={{false}}
        @title={{@title}}
        @type="custom"
        @validate={{@validate}}
        @validation={{this.validation}}
        as |field|
      >
        <field.Control>
          <BoardsEditableTitleUi
            @field={{field}}
            @onClose={{@onClose}}
            @placeholder={{@placeholder}}
            @showClose={{@showClose}}
          />
        </field.Control>
      </@form.Field>
    </div>
  </template>
}
