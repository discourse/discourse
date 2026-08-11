import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { makeArray } from "discourse/lib/helpers";
import ComboBox from "discourse/select-kit/components/combo-box";
import MultiSelect from "discourse/select-kit/components/multi-select";
import { inputFieldPathsForNode } from "../../../lib/workflows/input-fields";

export default class FieldPathControl extends Component {
  get multiple() {
    return Boolean(this.args.schema?.ui?.multiple);
  }

  get selected() {
    return String(this.args.field?.value ?? "").trim();
  }

  get selectedPaths() {
    return String(this.args.field?.value ?? "")
      .split(",")
      .map((path) => path.trim())
      .filter(Boolean);
  }

  get availablePaths() {
    return inputFieldPathsForNode(this.args.node, {
      nodes: this.args.nodes,
      connections: this.args.connections,
      nodeTypes: this.args.nodeTypes,
      session: this.args.session,
    });
  }

  get content() {
    const paths = this.availablePaths.map((entry) => entry.path);

    const missing = (
      this.multiple ? this.selectedPaths : [this.selected]
    ).filter((path) => path && !paths.includes(path));

    return [...paths, ...missing].map((path) => ({ id: path, name: path }));
  }

  get noneLabel() {
    return this.args.schema?.control_options?.none_label_i18n_key;
  }

  @action
  handleChange(value) {
    if (this.multiple) {
      this.args.field.set(makeArray(value).join(", "));
    } else {
      this.args.field.set(value ?? "");
    }
  }

  <template>
    {{#if this.multiple}}
      <MultiSelect
        class="workflows-field-path"
        @content={{this.content}}
        @value={{this.selectedPaths}}
        @nameProperty="name"
        @valueProperty="id"
        @onChange={{this.handleChange}}
        @options={{hash allowAny=true filterable=true none=this.noneLabel}}
      />
    {{else}}
      <ComboBox
        class="workflows-field-path"
        @content={{this.content}}
        @value={{this.selected}}
        @nameProperty="name"
        @valueProperty="id"
        @onChange={{this.handleChange}}
        @options={{hash allowAny=true filterable=true clearable=true}}
      />
    {{/if}}
  </template>
}
