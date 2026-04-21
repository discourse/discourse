import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DSegmentedControl from "discourse/components/d-segmented-control";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import {
  resolveVariableId,
  WORKFLOW_VARIABLE_MIME,
} from "../../../lib/workflows/expression-context";
import { isExpression } from "../../../lib/workflows/property-engine";
import ExpressionInput from "./expression-input";

const MODE_ITEMS = [
  {
    value: "plain",
    icon: "paragraph",
    label: i18n("discourse_workflows.parameter_field.plain"),
  },
  {
    value: "dynamic",
    icon: "code",
    label: i18n("discourse_workflows.parameter_field.dynamic"),
  },
];

export default class ExpressionWrapper extends Component {
  @service workflowsNodeTypes;

  @tracked isDragOver = false;
  dragEndHandler = null;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.dragEndHandler) {
      document.removeEventListener("dragend", this.dragEndHandler);
      this.dragEndHandler = null;
    }
  }

  get expressionMode() {
    return isExpression(this.args.field?.value);
  }

  @action
  toggleMode(value) {
    const wantsDynamic = value === "dynamic";
    if (wantsDynamic === this.expressionMode) {
      return;
    }

    const currentValue = this.args.field.value || "";

    if (wantsDynamic) {
      this.args.field.set(
        currentValue.startsWith("=") ? currentValue : `=${currentValue}`
      );
    } else {
      this.args.field.set(
        currentValue.startsWith("=") ? currentValue.slice(1) : currentValue
      );
    }
  }

  @action
  handleDragOver(event) {
    if (!this.args.supportsExpression) {
      return;
    }
    if (!event.dataTransfer.types.includes(WORKFLOW_VARIABLE_MIME)) {
      return;
    }
    event.preventDefault();
    event.dataTransfer.dropEffect = "copy";
    this.isDragOver = true;

    // Safety: clear on next dragend in case dragleave doesn't fire
    if (!this.dragEndHandler) {
      this.dragEndHandler = () => {
        this.isDragOver = false;
        document.removeEventListener("dragend", this.dragEndHandler);
        this.dragEndHandler = null;
      };
      document.addEventListener("dragend", this.dragEndHandler, {
        once: true,
      });
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
    this.isDragOver = false;

    if (!this.args.supportsExpression || this.expressionMode) {
      return;
    }

    const data = event.dataTransfer.getData(WORKFLOW_VARIABLE_MIME);
    if (!data) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    let variable;
    try {
      variable = JSON.parse(data);
    } catch {
      return;
    }

    const prefix =
      this.workflowsNodeTypes.expressionContext.item_prefix || "$json";
    const variableId = resolveVariableId(variable, prefix);

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
      {{#if this.expressionMode}}
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
          @items={{MODE_ITEMS}}
          @value={{if this.expressionMode "dynamic" "plain"}}
          @onSelect={{this.toggleMode}}
          @size="small"
          class="workflows-property-engine__mode-control"
        />
      {{/if}}
    </div>
  </template>
}
