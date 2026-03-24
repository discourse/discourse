import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";

function syncInputWidth(input) {
  input.style.setProperty(
    "--title-length",
    Math.max(input.value.length, 1) + 1
  );
}

const autosize = modifier((element) => {
  syncInputWidth(element);
  Promise.resolve().then(() => element.focus());
  const handler = () => syncInputWidth(element);
  element.addEventListener("input", handler);
  return () => element.removeEventListener("input", handler);
});

export default class WorkflowEditableTitle extends Component {
  @tracked isEditing = false;
  @tracked editValue = "";

  @action
  startEditing() {
    this.editValue = this.args.value;
    this.isEditing = true;
  }

  @action
  onInput(event) {
    this.editValue = event.target.value;
  }

  @action
  save() {
    this.isEditing = false;
    if (this.editValue.trim() && this.editValue !== this.args.value) {
      this.args.onSave(this.editValue.trim());
    }
  }

  @action
  handleKeydown(event) {
    if (event.key === "Enter") {
      this.save();
    } else if (event.key === "Escape") {
      this.isEditing = false;
    }
  }

  <template>
    <div class="workflows-editable-title">
      {{#if this.isEditing}}
        <input
          type="text"
          value={{this.editValue}}
          class="workflows-editable-title__input"
          {{autosize}}
          {{on "blur" this.save}}
          {{on "keydown" this.handleKeydown}}
          {{on "input" this.onInput}}
        />
      {{else}}
        <button
          type="button"
          class="workflows-editable-title__text"
          {{on "click" this.startEditing}}
        >{{@value}}</button>
      {{/if}}
    </div>
  </template>
}
