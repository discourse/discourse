import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class ExecutionDetail extends Component {
  formatJson(data) {
    if (!data || Object.keys(data).length === 0) {
      return "{}";
    }
    return JSON.stringify(data, null, 2);
  }

  formatDuration(startedAt, finishedAt) {
    if (!startedAt || !finishedAt) {
      return "—";
    }
    const ms = new Date(finishedAt) - new Date(startedAt);
    if (ms < 1000) {
      return `${ms}ms`;
    }
    return `${(ms / 1000).toFixed(1)}s`;
  }

  formatValue(value) {
    if (Array.isArray(value)) {
      return JSON.stringify(value);
    }
    if (value === null || value === undefined) {
      return "null";
    }
    return String(value);
  }

  formatLogs(logs) {
    return logs.join("\n");
  }

  isFilterStep(step) {
    return step.node_type === "condition:filter";
  }

  isConditionStep(step) {
    return step.node_type?.startsWith("condition:");
  }

  conditionPassed(step) {
    return step.status === "success";
  }

  isExpression(value) {
    return typeof value === "string" && value.startsWith("=");
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
      `Total time: ${this.formatDuration(execution.started_at, execution.finished_at)}`
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
        `  Duration: ${this.formatDuration(step.started_at, step.finished_at)}`
      );

      if (step.metadata?.conditions) {
        lines.push("  Conditions:");
        step.metadata.conditions.forEach((c) => {
          const result = c.passed ? "PASS" : "FAIL";
          const expr = c.leftExpression ? `${c.leftExpression} ` : "";
          lines.push(
            `    [${result}] ${expr}${this.formatValue(c.left)} ${c.operator} ${c.right != null ? this.formatValue(c.right) : ""}`
          );
        });
      }

      if (step.metadata?.logs?.length) {
        lines.push("  Console:");
        step.metadata.logs.forEach((log) => lines.push(`    ${log}`));
      }

      if (step.input && Object.keys(step.input).length > 0) {
        lines.push(
          `  Input: ${JSON.stringify(step.input, null, 2).replace(/\n/g, "\n    ")}`
        );
      }

      if (step.output && Object.keys(step.output).length > 0) {
        lines.push(
          `  Output: ${JSON.stringify(step.output, null, 2).replace(/\n/g, "\n    ")}`
        );
      }

      if (step.error) {
        lines.push(`  Error: ${step.error}`);
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
        <div class="workflows-execution-detail__error">
          {{@execution.error}}
        </div>
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
                {{#if (this.isFilterStep step)}}
                  {{if
                    (this.conditionPassed step)
                    (i18n "discourse_workflows.executions.statuses.kept")
                    (i18n "discourse_workflows.executions.statuses.rejected")
                  }}
                {{else if (this.isConditionStep step)}}
                  {{if
                    (this.conditionPassed step)
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
                {{this.formatDuration step.started_at step.finished_at}}
              </span>
            </div>

            <div class="workflows-execution-detail__step-body">
              {{#if step.metadata.conditions}}
                <div class="workflows-execution-detail__conditions">
                  {{#each step.metadata.conditions as |condition|}}
                    <div
                      class="workflows-execution-detail__condition
                        {{if condition.passed '--passed' '--failed'}}"
                    >
                      <span
                        class="workflows-execution-detail__condition-result"
                      >{{if condition.passed "✓" "✗"}}</span>
                      <span class="workflows-execution-detail__condition-value">
                        {{#if condition.leftExpression}}
                          <code
                            class="workflows-execution-detail__condition-field"
                          >{{condition.leftExpression}}</code>
                        {{/if}}
                        <code>{{this.formatValue condition.left}}</code>
                      </span>
                      <span
                        class="workflows-execution-detail__condition-operator"
                      >{{i18n
                          (concat
                            "discourse_workflows.if_condition.operators."
                            condition.operator
                          )
                        }}</span>
                      {{#if condition.right}}
                        <span
                          class="workflows-execution-detail__condition-value"
                        >
                          <code>{{this.formatValue condition.right}}</code>
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
                  <pre>{{this.formatLogs step.metadata.logs}}</pre>
                </details>
              {{/if}}

              <details class="workflows-execution-detail__step-section">
                <summary>{{i18n
                    "discourse_workflows.executions.input"
                  }}</summary>
                <pre>{{this.formatJson step.input}}</pre>
              </details>
              <details class="workflows-execution-detail__step-section">
                <summary>{{i18n
                    "discourse_workflows.executions.output"
                  }}</summary>
                <pre>{{this.formatJson step.output}}</pre>
              </details>
              {{#if step.error}}
                <div class="workflows-execution-detail__step-error">
                  <strong>{{i18n
                      "discourse_workflows.executions.error"
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
            {{this.formatDuration @execution.started_at @execution.finished_at}}
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
