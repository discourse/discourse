import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import { eq } from "discourse/truth-helpers";

const autofocus = modifier((element) => element.focus());

export default class CellEditor extends Component {
  @tracked isEditing = false;
  @tracked editValue = "";

  get columnType() {
    return this.args.column.type;
  }

  get isNull() {
    return this.args.value === null || this.args.value === undefined;
  }

  get isEmpty() {
    return this.args.value === "";
  }

  get isPlaceholder() {
    return this.isNull || this.isEmpty;
  }

  get displayValue() {
    if (this.isNull) {
      return "Null";
    }
    if (this.isEmpty) {
      return "Empty";
    }
    if (this.columnType === "date") {
      return this.formatDateValue(this.args.value);
    }
    return String(this.args.value);
  }

  @action
  startEditing() {
    if (this.columnType === "boolean") {
      return;
    }
    if (this.args.value === null || this.args.value === undefined) {
      this.editValue = "";
    } else if (this.columnType === "date") {
      this.editValue = this.formatDateValue(this.args.value);
    } else {
      this.editValue = String(this.args.value);
    }
    this.isEditing = true;
  }

  @action
  handleKeydown(event) {
    if (event.key === "Enter") {
      this.save();
    } else if (event.key === "Escape") {
      this.isEditing = false;
    }
  }

  @action
  save() {
    this.isEditing = false;
    this.args.onSave(this.args.column.name, this.editValue);
  }

  @action
  toggleBoolean() {
    const current = this.args.value;
    this.args.onSave(this.args.column.name, !current);
  }

  @action
  onInput(event) {
    this.editValue = event.target.value;
  }

  formatDateValue(value) {
    return String(value).slice(0, 10);
  }

  get inputType() {
    if (this.columnType === "number") {
      return "number";
    }
    if (this.columnType === "date") {
      return "date";
    }
    return "text";
  }

  <template>
    <td
      class="workflows-data-table-viewer__cell
        {{if (eq this.columnType 'boolean') '--boolean'}}"
    >
      {{#if (eq this.columnType "boolean")}}
        <input
          type="checkbox"
          checked={{@value}}
          class="workflows-data-table-viewer__checkbox"
          {{on "change" this.toggleBoolean}}
        />
      {{else if this.isEditing}}
        <input
          type={{this.inputType}}
          value={{this.editValue}}
          class="workflows-data-table-viewer__cell-input"
          {{autofocus}}
          {{on "blur" this.save}}
          {{on "keydown" this.handleKeydown}}
          {{on "input" this.onInput}}
        />
      {{else}}
        {{! template-lint-disable no-nested-interactive }}
        <button
          type="button"
          class="workflows-data-table-viewer__cell-value
            {{if this.isPlaceholder '--null'}}"
          {{on "click" this.startEditing}}
        >{{this.displayValue}}</button>
      {{/if}}
    </td>
  </template>
}
