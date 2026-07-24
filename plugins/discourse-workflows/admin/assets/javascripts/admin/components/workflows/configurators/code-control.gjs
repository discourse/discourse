import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { trustHTML } from "@ember/template";
import AceEditor from "discourse/components/ace-editor";
import { escapeExpression } from "discourse/lib/utilities";

export function normalizeCodeEditorValue(value, lang = "text") {
  if (value === null || value === undefined) {
    return "";
  }

  if (typeof value === "string") {
    return value;
  }

  if (lang?.toString() === "json" || typeof value === "object") {
    return JSON.stringify(value, null, 2);
  }

  return String(value);
}

export default class CodeControl extends Component {
  get height() {
    return this.args.schema?.control_options?.height;
  }

  get lang() {
    return this.args.schema?.control_options?.lang || "text";
  }

  get content() {
    return normalizeCodeEditorValue(this.args.field.value, this.lang);
  }

  get style() {
    if (!this.height) {
      return;
    }

    return trustHTML(`height: ${escapeExpression(this.height)}px`);
  }

  @action
  normalizeFieldValue() {
    if (this.content !== this.args.field.value) {
      this.args.field.set(this.content);
    }
  }

  @action
  handleInput(content) {
    this.args.field.set(content);
  }

  <template>
    <div class="workflows-code-control" {{didInsert this.normalizeFieldValue}}>
      <AceEditor
        @content={{this.content}}
        @onChange={{this.handleInput}}
        @mode={{this.lang}}
        @disabled={{@field.disabled}}
        @resizable={{true}}
        class="form-kit__control-code"
        style={{this.style}}
        id={{@field.id}}
        name={{@field.name}}
        aria-invalid={{if @field.error "true"}}
        aria-describedby={{@field.describedBy}}
      />
    </div>
  </template>
}
