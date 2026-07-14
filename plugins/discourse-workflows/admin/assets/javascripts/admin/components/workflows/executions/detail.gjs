import Component from "@glimmer/component";
import { array, concat } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  localeKeyPart,
  propertyOptionLabel,
} from "../../../lib/workflows/property-engine";

function formatJson(data) {
  if (!data || Object.keys(data).length === 0) {
    return "{}";
  }
  return JSON.stringify(data, null, 2);
}

function isTruncationMarker(value) {
  return value?.__truncated === true && value.__reason;
}

function truncationLabel(kind) {
  return i18n(`discourse_workflows.executions.truncated.${kind}`);
}

function truncationDetails(marker) {
  const details = [];

  if (marker.__original_bytes) {
    details.push(
      i18n("discourse_workflows.executions.truncated.original_bytes", {
        count: marker.__original_bytes,
      })
    );
  }

  if (marker.__original_size) {
    details.push(
      i18n("discourse_workflows.executions.truncated.original_size", {
        count: marker.__original_size,
      })
    );
  }

  if (marker.__max_bytes) {
    details.push(
      i18n("discourse_workflows.executions.truncated.max_bytes", {
        count: marker.__max_bytes,
      })
    );
  }

  return details.length ? ` (${details.join(", ")})` : "";
}

function formatTruncationMarker(marker, kind = "value") {
  return `${truncationLabel(kind)}${truncationDetails(marker)}`;
}

function replaceTruncationMarkers(value) {
  if (isTruncationMarker(value)) {
    return formatTruncationMarker(value);
  }

  if (Array.isArray(value)) {
    return value.map(replaceTruncationMarkers);
  }

  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, nestedValue]) => [
        key,
        replaceTruncationMarkers(nestedValue),
      ])
    );
  }

  return value;
}

function formatStepData(data, kind = "value") {
  if (isTruncationMarker(data)) {
    return formatTruncationMarker(data, kind);
  }

  data = replaceTruncationMarkers(data);

  if (!Array.isArray(data) || !data.every((i) => i?.json)) {
    return formatJson(data);
  }
  return formatJson(data.length === 1 ? data[0].json : data.map((i) => i.json));
}

function formatInputData(data) {
  return formatStepData(data, "input");
}

function formatOutputData(data) {
  return formatStepData(data, "output");
}

function itemCount(data) {
  return Array.isArray(data) && data.length > 1 && data.every((i) => i?.json)
    ? data.length
    : null;
}

function formatDuration(startedAt, finishedAt) {
  if (!startedAt || !finishedAt) {
    return "—";
  }
  const ms = new Date(finishedAt) - new Date(startedAt);
  return ms < 1000 ? `${ms}ms` : `${(ms / 1000).toFixed(1)}s`;
}

function formatValue(value) {
  if (Array.isArray(value)) {
    return JSON.stringify(value);
  }
  if (value === null || value === undefined) {
    return "null";
  }
  return String(value);
}

function conditionOperatorLabel(operator) {
  return i18n(`discourse_workflows.if.operators.${localeKeyPart(operator)}`);
}

function formatLogs(logs) {
  return logs
    .map((entry) => {
      if (typeof entry === "string") {
        return entry;
      }
      const prefix =
        entry.level === "error"
          ? "[error] "
          : entry.level === "warn"
            ? "[warn] "
            : "";
      if (entry.key !== undefined) {
        return `${prefix}${entry.key}: ${entry.value}`;
      }
      return `${prefix}${entry.message}`;
    })
    .join("\n");
}

function nodeKind(nodeType) {
  return nodeType?.split(":")[0] || "action";
}

const KIND_ICONS = {
  trigger: "bolt",
  condition: "arrows-split-up-and-left",
  action: "gear",
  flow: "arrows-split-up-and-left",
};

function kindIcon(nodeType) {
  return KIND_ICONS[nodeKind(nodeType)] || "gear";
}

function stepSummary(step) {
  if (!step.error) {
    return null;
  }
  return String(step.error);
}

function isFilterStep(step) {
  return step.node_type === "condition:filter";
}

function isConditionStep(step) {
  return step.node_type?.startsWith("condition:");
}

function conditionPassed(step) {
  return step.status === "success";
}

export default class ExecutionDetail extends Component {
  @service workflowsNodeTypes;

  operationLabel = (step) => {
    const value = step?.metadata?.operation;
    if (!value) {
      return null;
    }

    // Read tracked state so the template re-renders once node types load.
    if (!this.workflowsNodeTypes.nodeTypes) {
      return String(value);
    }

    const definition = this.workflowsNodeTypes.findNodeType(step.node_type);
    if (!definition) {
      return String(value);
    }

    return propertyOptionLabel(definition, "operation", { value });
  };

  @action
  async ensureNodeTypes() {
    await this.workflowsNodeTypes.load();
  }

  @action
  exportAsText() {
    const execution = this.args.execution;
    const lines = [];

    lines.push(`Workflow: ${execution.workflow_name ?? "Unknown"}`);
    lines.push(`Execution ID: ${execution.id}`);
    lines.push(`Status: ${execution.status}`);
    lines.push(`Started: ${execution.started_at ?? "—"}`);
    lines.push(`Finished: ${execution.finished_at ?? "—"}`);
    lines.push(
      `Total time: ${formatDuration(execution.started_at, execution.finished_at)}`
    );

    if (execution.error) {
      lines.push(`\nError: ${execution.error}`);
    }

    lines.push("\n" + "=".repeat(60));

    execution.steps?.forEach((step, index) => {
      lines.push(`\nStep ${index + 1}: ${step.node_name}`);
      lines.push(`  Type: ${step.node_type}`);
      const operationLabel = this.operationLabel(step);
      if (operationLabel) {
        lines.push(`  Operation: ${operationLabel}`);
      }
      lines.push(`  Status: ${step.status}`);
      lines.push(
        `  Duration: ${formatDuration(step.started_at, step.finished_at)}${step.metadata?.js_elapsed_ms ? ` (javascript: ${step.metadata.js_elapsed_ms}ms)` : ""}`
      );

      if (step.metadata?.conditions) {
        lines.push("  Conditions:");
        step.metadata.conditions.forEach((c) => {
          const result = c.passed ? "PASS" : "FAIL";
          const expr = c.leftExpression ? `${c.leftExpression} ` : "";
          lines.push(
            `    [${result}] ${expr}${formatValue(c.left)} ${c.operator} ${c.right != null ? formatValue(c.right) : ""}`
          );
        });
      }

      if (step.metadata?.logs?.length) {
        lines.push("  Console:");
        lines.push(
          ...formatLogs(step.metadata.logs)
            .split("\n")
            .map((l) => `    ${l}`)
        );
      }

      if (step.input && Object.keys(step.input).length > 0) {
        lines.push(
          `  Input: ${formatInputData(step.input).replace(/\n/g, "\n    ")}`
        );
      }

      if (step.output && Object.keys(step.output).length > 0) {
        lines.push(
          `  Output: ${formatOutputData(step.output).replace(/\n/g, "\n    ")}`
        );
      }

      if (step.error) {
        const label = step.status === "skipped" ? "Reason" : "Error";
        lines.push(`  ${label}: ${step.error}`);
      }

      lines.push("-".repeat(60));
    });

    const text = lines.join("\n");
    const blob = new Blob([text], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `discourse-workflows-execution-${execution.id}.txt`;
    a.click();
    URL.revokeObjectURL(url);
  }

  <template>
    <div class="workflows-execution-detail" {{didInsert this.ensureNodeTypes}}>
      {{#if @execution.workflow_call_caller}}
        <div class="workflows-execution-detail__workflow-call --caller">
          <div class="workflows-execution-detail__workflow-call-main">
            <span class="workflows-execution-detail__workflow-call-label">
              {{i18n "discourse_workflows.executions.workflow_call_called_by"}}
            </span>
            <span class="workflows-execution-detail__workflow-call-name">
              {{#if @execution.workflow_call_caller.workflow_name}}
                {{@execution.workflow_call_caller.workflow_name}}
              {{else}}
                {{i18n
                  "discourse_workflows.executions.workflow_call_workflow"
                  id=@execution.workflow_call_caller.workflow_id
                }}
              {{/if}}
            </span>
          </div>

          {{#if @execution.workflow_call_caller.execution_url}}
            <DButton
              @route="adminPlugins.show.discourse-workflows.show.executions.show"
              @routeModels={{array
                @execution.workflow_call_caller.workflow_id
                @execution.workflow_call_caller.execution_id
              }}
              @icon="up-right-from-square"
              @label="discourse_workflows.executions.workflow_call_open_parent"
              class="btn-default btn-small workflows-execution-detail__workflow-call-link workflows-execution-detail__workflow-call-parent-link"
            />
          {{/if}}
        </div>
      {{/if}}

      <div class="workflows-execution-detail__steps">
        {{#each @execution.steps as |step|}}
          <div
            class="workflows-execution-detail__step --{{step.status}}
              --kind-{{nodeKind step.node_type}}"
          >
            <div class="workflows-execution-detail__step-header">
              <span class="workflows-execution-detail__step-icon">
                {{dIcon (kindIcon step.node_type)}}
              </span>
              <span class="workflows-execution-detail__step-name">
                {{step.node_name}}
              </span>
              {{#let (this.operationLabel step) as |operationLabel|}}
                {{#if operationLabel}}
                  <span
                    class="workflows-execution-detail__step-operation"
                  >{{operationLabel}}</span>
                {{/if}}
              {{/let}}
              <span
                class="workflows-execution-detail__kind-badge --{{nodeKind
                    step.node_type
                  }}"
              >
                {{i18n
                  (concat
                    "discourse_workflows.executions.kinds."
                    (nodeKind step.node_type)
                  )
                }}
              </span>
              <span
                class="workflows-execution-detail__step-badge --{{step.status}}"
              >
                {{#if (isFilterStep step)}}
                  {{if
                    (conditionPassed step)
                    (i18n "discourse_workflows.executions.statuses.kept")
                    (i18n "discourse_workflows.executions.statuses.rejected")
                  }}
                {{else if (isConditionStep step)}}
                  {{if
                    (conditionPassed step)
                    (i18n "discourse_workflows.branch.true")
                    (i18n "discourse_workflows.branch.false")
                  }}
                {{else}}
                  {{i18n
                    (concat
                      "discourse_workflows.executions.statuses." step.status
                    )
                  }}
                {{/if}}
              </span>
              <span class="workflows-execution-detail__step-time">
                {{formatDuration step.started_at step.finished_at}}
                {{#if step.metadata.js_elapsed_ms}}
                  <span
                    class="workflows-execution-detail__step-js-time"
                  >(javascript: {{step.metadata.js_elapsed_ms}}ms)</span>
                {{/if}}
              </span>
            </div>

            {{#if (stepSummary step)}}
              <div class="workflows-execution-detail__step-summary">
                {{stepSummary step}}
              </div>
            {{/if}}

            <div class="workflows-execution-detail__step-body">
              {{#if step.metadata.conditions}}
                <div class="workflows-execution-detail__conditions">
                  {{#each step.metadata.conditions as |condition|}}
                    <div
                      class={{dConcatClass
                        "workflows-execution-detail__condition"
                        (if condition.passed "--passed" "--failed")
                      }}
                    >
                      <span
                        class="workflows-execution-detail__condition-result"
                      >{{if condition.passed "✓" "✗"}}</span>
                      <span class="workflows-execution-detail__condition-value">
                        {{#if condition.leftExpression}}
                          <code
                            class="workflows-execution-detail__condition-field"
                          >{{condition.leftExpression}}</code>
                          <span
                            class="workflows-execution-detail__condition-operator"
                          >{{i18n
                              "discourse_workflows.executions.with_value"
                            }}</span>
                        {{/if}}
                        <code>{{formatValue condition.left}}</code>
                      </span>
                      <span
                        class="workflows-execution-detail__condition-operator"
                      >{{conditionOperatorLabel condition.operator}}</span>
                      {{#if condition.right}}
                        <span
                          class="workflows-execution-detail__condition-value"
                        >
                          <code>{{formatValue condition.right}}</code>
                        </span>
                      {{/if}}
                    </div>
                  {{/each}}
                </div>
              {{/if}}

              {{#if step.metadata.logs}}
                <details class="workflows-execution-detail__step-section" open>
                  <summary>{{i18n
                      "discourse_workflows.executions.logs"
                    }}</summary>
                  <pre>{{formatLogs step.metadata.logs}}</pre>
                </details>
              {{/if}}

              {{#if step.workflow_call_run}}
                <div class="workflows-execution-detail__workflow-call">
                  <div class="workflows-execution-detail__workflow-call-main">
                    <span
                      class="workflows-execution-detail__workflow-call-icon"
                    >
                      {{dIcon "arrows-turn-to-dots"}}
                    </span>
                    <span
                      class="workflows-execution-detail__workflow-call-content"
                    >
                      <span
                        class="workflows-execution-detail__workflow-call-label"
                      >
                        {{i18n "discourse_workflows.executions.workflow_call"}}
                      </span>
                      <span
                        class="workflows-execution-detail__workflow-call-name"
                      >
                        {{#if step.workflow_call_run.workflow_name}}
                          {{step.workflow_call_run.workflow_name}}
                        {{else}}
                          {{i18n
                            "discourse_workflows.executions.workflow_call_workflow"
                            id=step.workflow_call_run.workflow_id
                          }}
                        {{/if}}
                      </span>
                    </span>
                  </div>

                  <span
                    class="workflows-execution-detail__step-badge --{{step.workflow_call_run.status}}"
                  >
                    {{i18n
                      (concat
                        "discourse_workflows.executions.statuses."
                        step.workflow_call_run.status
                      )
                    }}
                  </span>

                  {{#if step.workflow_call_run.execution_url}}
                    <DButton
                      @route="adminPlugins.show.discourse-workflows.show.executions.show"
                      @routeModels={{array
                        step.workflow_call_run.workflow_id
                        step.workflow_call_run.execution_id
                      }}
                      @icon="up-right-from-square"
                      @label="discourse_workflows.executions.workflow_call_open"
                      class="btn-default btn-small workflows-execution-detail__workflow-call-link"
                    />
                  {{/if}}

                  {{#if step.workflow_call_run.error}}
                    <div
                      class="workflows-execution-detail__workflow-call-error"
                    >
                      {{step.workflow_call_run.error}}
                    </div>
                  {{/if}}
                </div>
              {{/if}}

              <details class="workflows-execution-detail__step-section">
                <summary>
                  {{i18n "discourse_workflows.executions.input"}}
                  {{#if (itemCount step.input)}}
                    <span
                      class="workflows-execution-detail__item-count"
                    >{{itemCount step.input}}
                      {{i18n "discourse_workflows.executions.items"}}</span>
                  {{/if}}
                </summary>
                <pre>{{formatInputData step.input}}</pre>
              </details>
              <details class="workflows-execution-detail__step-section">
                <summary>
                  {{i18n "discourse_workflows.executions.output"}}
                  {{#if (itemCount step.output)}}
                    <span
                      class="workflows-execution-detail__item-count"
                    >{{itemCount step.output}}
                      {{i18n "discourse_workflows.executions.items"}}</span>
                  {{/if}}
                </summary>
                <pre>{{formatOutputData step.output}}</pre>
              </details>
            </div>
          </div>
        {{/each}}

        <div class="workflows-execution-detail__footer">
          <div class="workflows-execution-detail__total">
            {{i18n "discourse_workflows.executions.total_time"}}
            {{formatDuration @execution.started_at @execution.finished_at}}
          </div>
          <DButton
            @action={{this.exportAsText}}
            @icon="download"
            @label="discourse_workflows.executions.export"
            class="btn-default btn-small"
          />
        </div>
      </div>
    </div>
  </template>
}
