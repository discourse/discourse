import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";

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
  cancel() {
    this.isEditing = false;
  }

  @action
  onInput(event) {
    this.editValue = event.target.value;
  }

  @action
  save() {
    if (!this.isEditing) {
      return;
    }

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
      this.cancel();
    }
  }

  <template>
    <div class="workflows-editable-title">
      {{#if this.isEditing}}
        <input
          class="workflows-editable-title__input"
          type="text"
          value={{this.editValue}}
          {{autosize}}
          {{on "keydown" this.handleKeydown}}
          {{on "input" this.onInput}}
        />
        <div class="workflows-editable-title__actions">
          <DButton
            class="btn-flat workflows-editable-title__save"
            @action={{this.save}}
            @icon="check"
            @title="discourse_workflows.save"
          />
          <DButton
            class="btn-flat workflows-editable-title__cancel"
            @action={{this.cancel}}
            @icon="xmark"
            @title="discourse_workflows.cancel"
          />
        </div>
      {{else}}
        <div class="workflows-editable-title__display">
          <button
            class="workflows-editable-title__text"
            type="button"
            {{on "click" this.startEditing}}
          >{{@value}}</button>
          <DButton
            class="btn-flat workflows-editable-title__edit"
            @action={{this.startEditing}}
            @icon="pencil"
            @title="discourse_workflows.edit"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
