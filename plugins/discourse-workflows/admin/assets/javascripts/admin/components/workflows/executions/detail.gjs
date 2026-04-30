import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

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
      lines.push(`  Status: ${step.status}`);
      lines.push(
        `  Duration: ${formatDuration(step.started_at, step.finished_at)}`
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
    a.download = `execution-${execution.id}.txt`;
    a.click();
    URL.revokeObjectURL(url);
  }

  <template>
    <div class="workflows-execution-detail">
      {{#if @execution.error}}
        <pre
          class="workflows-execution-detail__error"
        >{{@execution.error}}</pre>
      {{/if}}

      <div class="workflows-execution-detail__steps">
        {{#each @execution.steps as |step|}}
          <div class="workflows-execution-detail__step --{{step.status}}">
            <div class="workflows-execution-detail__step-header">
              <span class="workflows-execution-detail__step-name">
                {{step.node_name}}
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
              </span>
            </div>

            <div class="workflows-execution-detail__step-body">
              {{#if step.metadata.conditions}}
                <div class="workflows-execution-detail__conditions">
                  {{#each step.metadata.conditions as |condition|}}
                    <div
                      class={{concatClass
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
                      >{{i18n
                          (concat
                            "discourse_workflows.if.operators."
                            condition.operator
                          )
                        }}</span>
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
              {{#if step.error}}
                <div
                  class="workflows-execution-detail__step-error --{{step.status}}"
                >
                  <strong>{{i18n
                      (if
                        (eq step.status "skipped")
                        "discourse_workflows.executions.reason"
                        "discourse_workflows.executions.error"
                      )
                    }}:</strong>
                  {{step.error}}
                </div>
              {{/if}}
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
