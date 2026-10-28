import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  checkFromEffect,
  checkSentence,
  effectSentence,
} from "../../../lib/workflows/workflow-test-checks.js";
import { buildDisclosure } from "../../../lib/workflows/workflow-test-disclosure.js";
import { workflowTestsStore } from "../../../lib/workflows/workflow-tests-store.js";
import ChecksBuilder from "./checks-builder.gjs";
import Disclosure from "./disclosure.gjs";
import StatusBadge from "./status-badge.gjs";

export default class TestEditor extends Component {
  @service messageBus;
  @service router;
  @service toasts;
  @service workflowsNodeTypes;

  @tracked test = null;
  @tracked formData = null;
  @tracked pastingFor = null;
  @tracked pasteBody = "";

  store = workflowTestsStore(this.args.workflow);

  nodeIcon = (entry) =>
    this.workflowsNodeTypes.findNodeType(entry.type)?.icon ||
    (entry.kind === "external" ? "globe" : "magnifying-glass");

  sentence = (check) => checkSentence(check);

  effectText = (effect) => effectSentence(effect);

  #onStoreUpdate = (tests) => this.#syncResult(tests);

  constructor() {
    super(...arguments);
    this.store.subscribe(this.messageBus);
    this.store.addListener(this.#onStoreUpdate);
    this.workflowsNodeTypes.load();
    this.#load();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.store.removeListener(this.#onStoreUpdate);
    this.store.unsubscribe();
  }

  get listEntry() {
    return this.store.tests.find((entry) => entry.id === this.test?.id);
  }

  get state() {
    return this.listEntry?.state ?? this.test.state;
  }

  get result() {
    return this.test.latest_result;
  }

  get triggerJson() {
    return JSON.stringify(this.test.trigger_data, null, 2);
  }

  get triggerNode() {
    return (this.args.workflow.nodes ?? []).find(
      (node) => node.id === this.test.trigger_node_id
    );
  }

  get disclosure() {
    return buildDisclosure({
      workflow: this.args.workflow,
      nodeTypeFor: (type) => this.workflowsNodeTypes.findNodeType(type),
      replaySteps: this.test.replay_steps,
      effects: this.result?.effects ?? [],
    });
  }

  get couldNotRun() {
    return this.result?.status === "could_not_run";
  }

  @action
  startPaste(entry) {
    this.pastingFor = entry.name;
    const current = this.test.pasted_responses?.[entry.name];
    this.pasteBody = current
      ? JSON.stringify(
          current.map((item) => item.json),
          null,
          2
        )
      : "";
  }

  @action
  updatePasteBody(event) {
    this.pasteBody = event.target.value;
  }

  @action
  async savePaste() {
    try {
      this.test = await this.store.pasteResponse(
        this.test.id,
        this.pastingFor,
        this.pasteBody
      );
      this.pastingFor = null;
      this.#toast("discourse_workflows.tests.editor.response_saved");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  cancelPaste() {
    this.pastingFor = null;
  }

  @action
  async refreshData() {
    await this.store.refreshData(this.test.id);
    this.#toast("discourse_workflows.tests.editor.data_refreshed");
  }

  @action
  addCheckFromEffect(form, effect) {
    form.addItemToCollection("checks", checkFromEffect(effect));
    this.#toast("discourse_workflows.tests.editor.check_added");
  }

  @action
  async runTest() {
    await this.store.run([this.test.id]);
  }

  @action
  async save(data) {
    try {
      this.test = await this.store.save(this.test.id, {
        name: data.name,
        checks: data.checks,
      });
      this.#toast("discourse_workflows.tests.saved");
      this.router.transitionTo(
        "adminPlugins.show.discourse-workflows.show.workflow-tests.index",
        this.args.workflow.id
      );
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async #load() {
    try {
      this.test = await this.store.find(this.args.testId);
      this.formData = {
        name: this.test.name,
        checks: structuredClone(this.test.checks),
      };
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async #syncResult(tests) {
    const entry = tests.find((candidate) => candidate.id === this.test?.id);
    if (
      !entry ||
      entry.state === "running" ||
      entry.latest_execution_id === this.test.latest_execution_id
    ) {
      return;
    }

    try {
      const fresh = await this.store.find(this.test.id);
      if (!this.isDestroying) {
        this.test = fresh;
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  #toast(key) {
    this.toasts.success({
      duration: "short",
      data: { message: i18n(key) },
    });
  }

  <template>
    {{#if this.test}}
      <Form
        class="workflows-test-editor"
        @data={{this.formData}}
        @onSubmit={{this.save}}
        as |form|
      >
        <AdminConfigAreaCard @heading="discourse_workflows.tests.editor.name">
          <:content>
            <form.Field
              @format="large"
              @name="name"
              @title={{i18n "discourse_workflows.tests.editor.name"}}
              @type="input"
              @validation="required"
              as |field|
            >
              <field.Control
                placeholder={{i18n
                  "discourse_workflows.tests.editor.name_placeholder"
                }}
              />
            </form.Field>
          </:content>
        </AdminConfigAreaCard>

        <AdminConfigAreaCard
          @heading="discourse_workflows.tests.editor.input_title"
        >
          <:content>
            <div class="workflows-test-editor__source">
              <span class="workflows-test-editor__source-text">
                {{dIcon "clock"}}
                {{i18n
                  "discourse_workflows.tests.editor.input_from"
                  id=this.test.source_execution_id
                }}
                {{#if this.test.captured_at}}
                  ·
                  {{i18n "discourse_workflows.tests.editor.captured_on"}}
                  {{dFormatDate this.test.captured_at format="medium"}}
                {{/if}}
              </span>
              <DButton
                class="btn-default btn-small"
                @action={{this.refreshData}}
                @disabled={{this.store.running}}
                @icon="arrows-rotate"
                @label="discourse_workflows.tests.editor.refresh_data"
              />
            </div>
            <p class="admin-config-area-card__description">
              {{i18n "discourse_workflows.tests.editor.input_description"}}
            </p>

            <details class="workflows-test-editor__details">
              <summary>
                {{i18n "discourse_workflows.tests.editor.trigger_data"}}
                {{#if this.triggerNode}}
                  ·
                  {{i18n
                    "discourse_workflows.tests.editor.trigger_data_help"
                    node=this.triggerNode.name
                  }}
                {{/if}}
              </summary>
              <pre
                class="workflows-test-editor__json"
              >{{this.triggerJson}}</pre>
            </details>
          </:content>
        </AdminConfigAreaCard>

        {{#if this.test.replay_steps.length}}
          <AdminConfigAreaCard
            @heading="discourse_workflows.tests.editor.captured_title"
          >
            <:content>
              <p class="admin-config-area-card__description">
                {{i18n "discourse_workflows.tests.editor.captured_description"}}
              </p>
              <ul class="workflows-test-editor__nodes">
                {{#each this.test.replay_steps as |entry|}}
                  <li
                    class={{dConcatClass
                      "workflows-test-editor__node"
                      (if entry.needs_response "--needs-response")
                    }}
                  >
                    <span class="workflows-test-editor__node-icon">
                      {{dIcon (this.nodeIcon entry)}}
                    </span>
                    <span class="workflows-test-editor__node-name">
                      {{entry.name}}
                    </span>
                    {{#if (eq entry.kind "external")}}
                      {{#if entry.needs_response}}
                        <span
                          class="workflows-test-editor__node-state --needs-response"
                        >
                          {{dIcon "triangle-exclamation"}}
                          {{i18n
                            "discourse_workflows.tests.editor.needs_response"
                          }}
                        </span>
                      {{else}}
                        <span class="workflows-test-editor__node-state">
                          {{dIcon "circle-check"}}
                          {{i18n
                            "discourse_workflows.tests.editor.replayed_response"
                          }}
                        </span>
                      {{/if}}
                      {{#unless (eq this.pastingFor entry.name)}}
                        <DButton
                          class="btn-default btn-small"
                          @action={{fn this.startPaste entry}}
                          @icon="paste"
                          @translatedLabel={{i18n
                            "discourse_workflows.tests.editor.paste_response"
                            step=entry.name
                          }}
                        />
                      {{/unless}}
                    {{else if entry.captured}}
                      <span class="workflows-test-editor__node-state">
                        {{dIcon "circle-check"}}
                        {{i18n "discourse_workflows.tests.editor.captured_on"}}
                        {{dFormatDate this.test.captured_at format="medium"}}
                      </span>
                    {{else}}
                      <span class="workflows-test-editor__node-state --pending">
                        {{dIcon "circle"}}
                        {{i18n "discourse_workflows.tests.editor.not_captured"}}
                      </span>
                    {{/if}}

                    {{#if (eq this.pastingFor entry.name)}}
                      <div class="workflows-test-editor__paste">
                        <label
                          class="workflows-test-editor__paste-label"
                          for={{concat "paste-" entry.name}}
                        >
                          {{i18n
                            "discourse_workflows.tests.editor.paste_help"
                            step=entry.name
                          }}
                        </label>
                        <textarea
                          class="workflows-test-editor__paste-input"
                          id={{concat "paste-" entry.name}}
                          rows="5"
                          {{on "input" this.updatePasteBody}}
                        >{{this.pasteBody}}</textarea>
                        <div class="workflows-test-editor__paste-actions">
                          <DButton
                            class="btn-primary btn-small"
                            @action={{this.savePaste}}
                            @label="discourse_workflows.tests.editor.save_response"
                          />
                          <DButton
                            class="btn-flat btn-small"
                            @action={{this.cancelPaste}}
                            @label="cancel"
                          />
                        </div>
                      </div>
                    {{/if}}
                  </li>
                {{/each}}
              </ul>
            </:content>
          </AdminConfigAreaCard>
        {{/if}}

        <AdminConfigAreaCard
          @heading="discourse_workflows.tests.editor.checks_title"
        >
          <:content>
            <p class="admin-config-area-card__description">
              {{i18n "discourse_workflows.tests.editor.checks_description"}}
            </p>
            <div class="workflows-test-checks">
              <ChecksBuilder
                @effectTypes={{this.workflowsNodeTypes.effectTypes}}
                @form={{form}}
              />
            </div>
          </:content>
        </AdminConfigAreaCard>

        <AdminConfigAreaCard
          @heading="discourse_workflows.tests.editor.result_title"
        >
          <:content>
            {{#if this.result}}
              <p class="admin-config-area-card__description">
                <StatusBadge @status={{this.state}} />
                {{i18n "discourse_workflows.tests.editor.result_description"}}
                {{dFormatDate this.result.finished_at format="medium"}}
              </p>

              {{#if this.couldNotRun}}
                <div class="workflows-test-editor__notice --could-not-run">
                  {{dIcon "ban"}}
                  <span>{{this.result.reason}}</span>
                </div>
              {{else}}
                {{#if (eq this.result.error_kind "node")}}
                  <div class="workflows-test-editor__notice --failed">
                    {{dIcon "circle-xmark"}}
                    <span>{{this.result.reason}}</span>
                  </div>
                {{/if}}

                <h4 class="workflows-test-editor__subheading">
                  {{i18n "discourse_workflows.tests.editor.effects_title"}}
                </h4>
                {{#if this.result.effects.length}}
                  <ul class="workflows-test-editor__effects">
                    {{#each this.result.effects as |effect|}}
                      <li class="workflows-test-editor__effect">
                        {{dIcon "bolt"}}
                        <span class="workflows-test-editor__effect-text">
                          {{this.effectText effect}}
                        </span>
                        <DButton
                          class="btn-flat btn-small workflows-test-editor__add-check"
                          @action={{fn this.addCheckFromEffect form effect}}
                          @icon="plus"
                          @label="discourse_workflows.tests.editor.add_as_check"
                        />
                      </li>
                    {{/each}}
                  </ul>
                {{else}}
                  <p class="workflows-test-editor__no-effects">
                    {{i18n "discourse_workflows.tests.editor.no_effects"}}
                  </p>
                {{/if}}

                <Disclosure @disclosure={{this.disclosure}} />

                <h4 class="workflows-test-editor__subheading">
                  {{i18n "discourse_workflows.tests.editor.checks_title"}}
                </h4>
                <ul class="workflows-test-editor__results">
                  {{#each this.result.checks as |entry|}}
                    <li class="workflows-test-editor__result">
                      <StatusBadge @status={{entry.status}} />
                      <span>{{this.sentence entry}}</span>
                      {{#if entry.reason}}
                        <span class="workflows-test-editor__result-reason">
                          {{entry.reason}}
                        </span>
                      {{/if}}
                    </li>
                  {{/each}}
                </ul>
              {{/if}}
            {{else}}
              <p class="admin-config-area-card__description">
                {{i18n "discourse_workflows.tests.editor.no_result"}}
              </p>
            {{/if}}
          </:content>
        </AdminConfigAreaCard>

        <div class="workflows-test-editor__actions">
          <form.Submit @label="discourse_workflows.tests.save" />
          <DButton
            class="btn-default"
            @action={{this.runTest}}
            @icon="play"
            @isLoading={{this.store.running}}
            @label="discourse_workflows.tests.run_test"
          />
        </div>
      </Form>
    {{/if}}
  </template>
}
