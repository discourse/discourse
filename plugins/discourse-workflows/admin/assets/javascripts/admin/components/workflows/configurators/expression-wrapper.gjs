import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DSegmentedControl from "discourse/components/d-segmented-control";
import concatClass from "discourse/helpers/concat-class";
import ExpressionInput from "./expression-input";

export default class ExpressionWrapper extends Component {
  @service workflowsNodeTypes;

  @tracked isDragOver = false;

  @action
  handleDragOver(event) {
    if (!this.args.supportsExpression || this.args.expressionMode) {
      return;
    }
    if (event.dataTransfer.types.includes("application/x-workflow-variable")) {
      event.preventDefault();
      event.dataTransfer.dropEffect = "copy";
      this.isDragOver = true;
    }
  }

  @action
  handleDragLeave(event) {
    if (!event.currentTarget.contains(event.relatedTarget)) {
      this.isDragOver = false;
    }
  }

  @action
  handleDrop(event) {
    if (!this.args.supportsExpression || this.args.expressionMode) {
      return;
    }

    const data = event.dataTransfer.getData("application/x-workflow-variable");
    if (!data) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    this.isDragOver = false;

    let variable;
    try {
      variable = JSON.parse(data);
    } catch {
      return;
    }

    const prefix =
      this.workflowsNodeTypes.expressionContext.item_prefix || "$json";
    const variableId = variable.id.startsWith("$")
      ? variable.id
      : `${prefix}.${variable.id}`;

    this.args.onModeChange("dynamic");
    this.args.field.set(`={{ ${variableId} }}`);
  }

  <template>
    <div
      class={{concatClass
        "workflows-property-engine__control-wrapper"
        (if this.isDragOver "is-drag-over")
      }}
      data-supports-expression={{if @supportsExpression "true"}}
      {{on "dragover" this.handleDragOver}}
      {{on "dragleave" this.handleDragLeave}}
      {{on "drop" this.handleDrop}}
    >
      {{#if @expressionMode}}
        <ExpressionInput
          @field={{@field}}
          @placeholder={{@placeholder}}
          @autofocus={{true}}
        />
      {{else}}
        {{yield}}
      {{/if}}

      {{#if @supportsExpression}}
        <DSegmentedControl
          @items={{@modeItems}}
          @value={{if @expressionMode "dynamic" "plain"}}
          @onSelect={{@onModeChange}}
          @size="small"
          class="workflows-property-engine__mode-control"
        />
      {{/if}}
    </div>
  </template>
}
