import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import AceEditor from "discourse/components/ace-editor";
import { escapeExpression } from "discourse/lib/utilities";

export default class PropertyEngineCode extends Component {
  get heightStyle() {
    const height = this.args.schema?.ui?.height;

    if (!height) {
      return;
    }

    return trustHTML(`height: ${escapeExpression(height)}px`);
  }

  get mode() {
    return this.args.schema?.ui?.lang || "text";
  }

  @action
  handleChange(value) {
    this.args.onPatch?.({ [this.args.fieldName]: value });
  }

  <template>
    <AceEditor
      @content={{@value}}
      @mode={{this.mode}}
      @onChange={{this.handleChange}}
      @resizable={{true}}
      class="workflows-property-engine__code"
      style={{this.heightStyle}}
    />
  </template>
}
