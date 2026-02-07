import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";

export default class CssEditorVariable extends Component {
  @service cssEditorState;

  get isColor() {
    return this.args.variable.type === "color";
  }

  get isModified() {
    return this.cssEditorState.overrides.has(this.args.variable.name);
  }

  get currentValue() {
    return this.cssEditorState.getCurrentValue(this.args.variable.name);
  }

  get colorHex() {
    return this.cssEditorState.getColorHex(this.args.variable.name);
  }

  @action
  onTextInput(event) {
    this.cssEditorState.setVariable(
      this.args.variable.name,
      event.target.value
    );
  }

  @action
  onColorInput(event) {
    this.cssEditorState.setVariable(
      this.args.variable.name,
      event.target.value
    );
  }

  @action
  reset() {
    this.cssEditorState.resetVariable(this.args.variable.name);
  }

  <template>
    <div class="css-editor-variable {{if this.isModified 'is-modified'}}">
      <div class="css-editor-variable__name">{{@variable.name}}</div>
      <div class="css-editor-variable__controls">
        {{#if this.isColor}}
          <input
            type="color"
            value={{this.colorHex}}
            class="css-editor-variable__color-picker"
            {{on "input" this.onColorInput}}
          />
        {{/if}}
        <input
          type="text"
          value={{this.currentValue}}
          class="css-editor-variable__text-input"
          {{on "change" this.onTextInput}}
        />
        {{#if this.isModified}}
          <button
            type="button"
            class="css-editor-variable__reset btn-flat btn-icon no-text"
            title="Reset"
            {{on "click" this.reset}}
          >
            {{icon "arrow-rotate-left"}}
          </button>
        {{/if}}
      </div>
    </div>
  </template>
}
