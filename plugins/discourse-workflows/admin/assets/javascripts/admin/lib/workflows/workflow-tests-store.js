import { tracked } from "@glimmer/tracking";
import { cancel } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";

const EXECUTIONS_CHANNEL = "/discourse-workflows/executions";
const FINISHED_STATUSES = ["success", "error", "skipped", "rate_limited"];
const POLL_INTERVAL_MS = 2000;
const POLL_DEADLINE_MS = 10 * 60 * 1000;

const stores = new Map();
const autoRuns = new Set();
const autoPreviews = new Set();

function basePath(workflowId) {
  return `/admin/plugins/discourse-workflows/workflows/${workflowId}`;
}

function jsonRequest(url, type, data) {
  return ajax(url, {
    type,
    contentType: "application/json",
    data: JSON.stringify(data ?? {}),
  });
}

function errorMessage(error) {
  const errors = error?.jqXHR?.responseJSON?.errors;
  return Array.isArray(errors) && errors.length ? errors[0] : null;
}

export class WorkflowTestsStore {
  @tracked tests = [];
  @tracked loaded = false;
  @tracked busy = false;
  @tracked preview = null;

  #messageBus = null;
  #messageHandler = null;
  #subscribers = 0;
  #loadSequence = 0;
  #previewExecutionId = null;
  #listeners = new Set();
  #pollTimer = null;
  #pollStartedAt = null;

  constructor(workflowId) {
    this.workflowId = workflowId;
  }

  get running() {
    return this.busy || this.tests.some((test) => test.state === "running");
  }

  get summary() {
    const count = (state) =>
      this.tests.filter((test) => test.state === state).length;
    return {
      total: this.tests.length,
      passed: count("passed"),
      failed: count("failed"),
      couldNotRun: count("could_not_run"),
      notRun: count("not_run") + count("run_again"),
      running: count("running"),
    };
  }

  get allPassing() {
    const summary = this.summary;
    return summary.total > 0 && summary.passed === summary.total;
  }

  get #waiting() {
    return (
      this.#previewExecutionId !== null ||
      this.tests.some((test) => test.state === "running")
    );
  }

  subscribe(messageBus) {
    this.#subscribers += 1;
    if (this.#messageBus) {
      return;
    }

    this.#messageBus = messageBus;
    this.#messageHandler = (message) => this.#onExecutionMessage(message);
    messageBus.subscribe(EXECUTIONS_CHANNEL, this.#messageHandler);
  }

  unsubscribe() {
    this.#subscribers = Math.max(0, this.#subscribers - 1);
    if (!this.#messageBus || this.#subscribers > 0) {
      return;
    }

    this.#messageBus.unsubscribe(EXECUTIONS_CHANNEL, this.#messageHandler);
    this.#messageBus = null;
    this.#messageHandler = null;
    this.#stopPolling();
  }

  addListener(callback) {
    this.#listeners.add(callback);
  }

  removeListener(callback) {
    this.#listeners.delete(callback);
  }

  async load() {
    const sequence = ++this.#loadSequence;
    try {
      const result = await ajax(`${basePath(this.workflowId)}/tests.json`);
      if (sequence === this.#loadSequence) {
        this.tests = result.tests ?? [];
        this.loaded = true;
        this.#listeners.forEach((callback) => callback(this.tests));
        this.#syncPolling();
      }
    } catch (error) {
      popupAjaxError(error);
    }
    return this.tests;
  }

  async find(testId) {
    const result = await ajax(
      `${basePath(this.workflowId)}/tests/${testId}.json`
    );
    this.#mergeListEntry(result.test);
    return result.test;
  }

  async createFromExecution(executionId, name = null) {
    const result = await jsonRequest(
      `${basePath(this.workflowId)}/tests.json`,
      "POST",
      { execution_id: executionId, name }
    );
    this.#mergeListEntry(result.test);
    return result.test;
  }

  async save(testId, attributes) {
    const result = await jsonRequest(
      `${basePath(this.workflowId)}/tests/${testId}.json`,
      "PUT",
      attributes
    );
    this.#mergeListEntry(result.test);
    return result.test;
  }

  pasteResponse(testId, nodeName, body) {
    return this.save(testId, { pasted_responses: { [nodeName]: body } });
  }

  async remove(testId) {
    try {
      await ajax(`${basePath(this.workflowId)}/tests/${testId}.json`, {
        type: "DELETE",
      });
      this.tests = this.tests.filter((test) => test.id !== testId);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async run(testIds = []) {
    this.busy = true;
    try {
      await jsonRequest(`${basePath(this.workflowId)}/tests/run.json`, "POST", {
        test_ids: testIds,
      });
      await this.load();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  async refreshData(testId) {
    this.busy = true;
    try {
      await jsonRequest(
        `${basePath(this.workflowId)}/tests/${testId}/refresh.json`,
        "POST"
      );
      await this.load();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  async startPreview(triggerNodeId) {
    this.preview = { status: "running" };
    try {
      const result = await jsonRequest(
        `${basePath(this.workflowId)}/previews.json`,
        "POST",
        { trigger_node_id: triggerNodeId }
      );
      this.#previewExecutionId = result.execution.id;
      this.preview = { status: "running", executionId: result.execution.id };
      await this.#loadPreviewResult(result.execution.id);
      this.#syncPolling();
    } catch (error) {
      const message = errorMessage(error);
      if (message) {
        this.preview = { status: "refused", message };
      } else {
        this.preview = null;
        popupAjaxError(error);
      }
    }
    return this.preview;
  }

  dismissPreview() {
    this.preview = null;
    this.#previewExecutionId = null;
    this.#syncPolling();
  }

  takeAutoRun() {
    return takeFlag(autoRuns, this.workflowId);
  }

  takeAutoPreview() {
    return takeFlag(autoPreviews, this.workflowId);
  }

  #syncPolling() {
    if (!this.#waiting) {
      this.#stopPolling();
      return;
    }
    if (this.#pollTimer !== null) {
      return;
    }

    this.#pollStartedAt ??= Date.now();
    if (Date.now() - this.#pollStartedAt > POLL_DEADLINE_MS) {
      this.#stopPolling();
      return;
    }

    this.#pollTimer = discourseLater(() => this.#poll(), POLL_INTERVAL_MS);
  }

  #stopPolling() {
    if (this.#pollTimer !== null) {
      cancel(this.#pollTimer);
      this.#pollTimer = null;
    }
    this.#pollStartedAt = null;
  }

  async #poll() {
    this.#pollTimer = null;
    if (this.#previewExecutionId !== null) {
      await this.#loadPreviewResult(this.#previewExecutionId);
    }
    if (this.tests.some((test) => test.state === "running")) {
      await this.load();
    }
    this.#syncPolling();
  }

  async #loadPreviewResult(executionId) {
    try {
      const result = await ajax(
        `/admin/plugins/discourse-workflows/executions/${executionId}.json`
      );
      const execution = result.execution;
      if (!FINISHED_STATUSES.includes(execution.status)) {
        return;
      }

      this.#previewExecutionId = null;
      this.#syncPolling();
      const simulation = execution.simulation ?? {};
      this.preview = {
        status: "done",
        executionId: execution.id,
        effects: simulation.effects ?? [],
        totalEffectCount: simulation.total_effect_count ?? 0,
        errorKind: simulation.error_kind ?? null,
        failedStep: simulation.failed_step ?? null,
        error: execution.error ?? null,
      };
    } catch (error) {
      this.preview = null;
      popupAjaxError(error);
    }
  }

  #mergeListEntry(test) {
    const exists = this.tests.some((entry) => entry.id === test.id);
    this.tests = exists
      ? this.tests.map((entry) =>
          entry.id === test.id ? { ...entry, ...test } : entry
        )
      : [...this.tests, test];
  }

  #onExecutionMessage(message) {
    const execution = message?.execution;
    if (
      !execution ||
      execution.workflow_id !== Number(this.workflowId) ||
      execution.execution_mode !== "simulation" ||
      !FINISHED_STATUSES.includes(execution.status)
    ) {
      return;
    }

    if (execution.id === this.#previewExecutionId) {
      this.#loadPreviewResult(execution.id);
      return;
    }

    if (this.loaded) {
      this.load();
    }
  }
}

function takeFlag(set, workflowId) {
  const key = `${workflowId}`;
  const flagged = set.has(key);
  set.delete(key);
  return flagged;
}

export function workflowTestsStore(workflowOrId) {
  const key = `${workflowOrId?.id ?? workflowOrId}`;
  if (!stores.has(key)) {
    stores.set(key, new WorkflowTestsStore(key));
  }
  return stores.get(key);
}

export function requestAutoRun(workflowId) {
  autoRuns.add(`${workflowId}`);
}

export function requestPreview(workflowId) {
  autoPreviews.add(`${workflowId}`);
}
