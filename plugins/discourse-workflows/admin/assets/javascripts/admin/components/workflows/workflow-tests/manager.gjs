import Component from "@glimmer/component";
import { array, concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { effectSentence } from "../../../lib/workflows/workflow-test-checks.js";
import { buildDisclosure } from "../../../lib/workflows/workflow-test-disclosure.js";
import { workflowTestsStore } from "../../../lib/workflows/workflow-tests-store.js";
import AdminTable from "../admin-table.gjs";
import EmptyState from "../empty-state.gjs";
import Disclosure from "./disclosure.gjs";
import StatusBadge from "./status-badge.gjs";

export default class TestsManager extends Component {
  @service dialog;
  @service messageBus;
  @service router;
  @service workflowsNodeTypes;

  store = workflowTestsStore(this.args.workflow);

  effectText = (effect) => effectSentence(effect);

  constructor() {
    super(...arguments);
    this.store.subscribe(this.messageBus);
    this.workflowsNodeTypes.load();
    this.#start();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.store.unsubscribe();
  }

  get preview() {
    return this.store.preview;
  }

  get previewDisclosure() {
    return buildDisclosure({
      workflow: this.args.workflow,
      nodeTypeFor: (type) => this.workflowsNodeTypes.findNodeType(type),
      effects: this.preview?.effects ?? [],
      preview: true,
    });
  }

  get summary() {
    return this.store.summary;
  }

  get summaryStatus() {
    if (!this.store.loaded || !this.summary.total) {
      return null;
    }
    if (this.summary.failed > 0 || this.summary.couldNotRun > 0) {
      return "failed";
    }
    if (this.store.allPassing) {
      return "passed";
    }
    return null;
  }

  get summaryText() {
    if (this.summary.failed > 0) {
      return i18n("discourse_workflows.tests.summary.some_failed", {
        count: this.summary.failed,
      });
    }
    if (this.summary.couldNotRun > 0) {
      return i18n("discourse_workflows.tests.summary.could_not_run", {
        count: this.summary.couldNotRun,
      });
    }
    return i18n("discourse_workflows.tests.summary.all_passed", {
      count: this.summary.total,
    });
  }

  get triggerNode() {
    return (this.args.workflow.nodes ?? []).find((node) =>
      node.type?.startsWith("trigger:")
    );
  }

  @action
  runAll() {
    this.store.run();
  }

  @action
  runOne(test) {
    this.store.run([test.id]);
  }

  @action
  previewNow() {
    this.store.startPreview(this.triggerNode?.id);
  }

  @action
  dismissPreview() {
    this.store.dismissPreview();
  }

  @action
  async saveTestFromPreview() {
    try {
      const test = await this.store.createFromExecution(
        this.preview.executionId
      );
      this.store.dismissPreview();
      this.router.transitionTo(
        "adminPlugins.show.discourse-workflows.show.workflow-tests.show",
        this.args.workflow.id,
        test.id
      );
    } catch (error) {
      this.dialog.alert(
        error?.jqXHR?.responseJSON?.errors?.[0] ?? error.message
      );
    }
  }

  @action
  goToExecutions() {
    this.router.transitionTo(
      "adminPlugins.show.discourse-workflows.show.executions",
      this.args.workflow.id
    );
  }

  @action
  deleteTest(test) {
    this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.tests.delete_confirm", {
        name: test.name,
      }),
      didConfirm: () => this.store.remove(test.id),
    });
  }

  async #start() {
    await this.store.load();
    if (this.store.takeAutoRun() && this.store.tests.length) {
      this.runAll();
    }
    if (this.store.takeAutoPreview()) {
      this.previewNow();
    }
  }

  <template>
    <DPageSubheader
      @descriptionLabel={{i18n "discourse_workflows.tests.description"}}
      @titleLabel={{i18n "discourse_workflows.tests.title"}}
    >
      <:actions as |actions|>
        <actions.Default
          class="workflows-tests-manager__preview-btn"
          @action={{this.previewNow}}
          @icon="bolt"
          @isLoading={{eq this.preview.status "running"}}
          @label="discourse_workflows.tests.preview_now"
        />
        {{#if this.store.tests.length}}
          <actions.Primary
            class="workflows-tests-manager__run-all"
            @action={{this.runAll}}
            @icon="play"
            @isLoading={{this.store.running}}
            @label="discourse_workflows.tests.run_all"
          />
        {{/if}}
      </:actions>
    </DPageSubheader>

    {{#if this.preview}}
      <section
        class={{dConcatClass
          "workflows-tests-manager__preview"
          (if (eq this.preview.status "refused") "--refused")
        }}
      >
        {{#if (eq this.preview.status "refused")}}
          <div class="workflows-tests-manager__preview-header">
            <h3 class="workflows-tests-manager__preview-title">
              {{dIcon "circle-info"}}
              {{i18n "discourse_workflows.tests.preview.no_sample_input_title"}}
            </h3>
          </div>
          <p class="workflows-tests-manager__preview-note">
            {{this.preview.message}}
          </p>
          <div class="workflows-tests-manager__preview-actions">
            <DButton
              class="btn-default btn-small"
              @label="discourse_workflows.tests.preview.go_to_executions"
              @route="adminPlugins.show.discourse-workflows.show.executions"
              @routeModels={{array @workflow.id}}
            />
            <DButton
              class="btn-flat btn-small"
              @action={{this.dismissPreview}}
              @label="discourse_workflows.tests.preview.dismiss"
            />
          </div>
        {{else if (eq this.preview.status "running")}}
          <div class="workflows-tests-manager__preview-header">
            <h3 class="workflows-tests-manager__preview-title">
              {{dIcon "bolt"}}
              {{i18n "discourse_workflows.tests.preview.running"}}
            </h3>
          </div>
        {{else}}
          <div class="workflows-tests-manager__preview-header">
            <h3 class="workflows-tests-manager__preview-title">
              {{dIcon "bolt"}}
              {{i18n "discourse_workflows.tests.preview.title"}}
            </h3>
            <span class="workflows-tests-manager__summary-meta">
              {{i18n "discourse_workflows.tests.preview.description"}}
            </span>
          </div>
          {{#if this.preview.error}}
            <div
              class={{dConcatClass
                "workflows-test-editor__notice"
                (if
                  (eq this.preview.errorKind "node")
                  "--failed"
                  "--could-not-run"
                )
              }}
            >
              {{dIcon "circle-xmark"}}
              <span>{{this.preview.error}}</span>
            </div>
          {{/if}}
          {{#if this.preview.effects.length}}
            <ul class="workflows-test-editor__effects">
              {{#each this.preview.effects as |effect|}}
                <li class="workflows-test-editor__effect">
                  {{dIcon "bolt"}}
                  {{this.effectText effect}}
                </li>
              {{/each}}
            </ul>
          {{else}}
            <p class="workflows-test-editor__no-effects">
              {{i18n "discourse_workflows.tests.editor.no_effects"}}
            </p>
          {{/if}}
          <Disclosure @disclosure={{this.previewDisclosure}} />
          <div class="workflows-tests-manager__preview-actions">
            <DButton
              class="btn-primary btn-small"
              @action={{this.saveTestFromPreview}}
              @icon="flask"
              @label="discourse_workflows.tests.save_as_test"
            />
            <DButton
              class="btn-default btn-small"
              @action={{this.dismissPreview}}
              @label="discourse_workflows.tests.preview.dismiss"
            />
          </div>
        {{/if}}
      </section>
    {{/if}}

    {{#if this.summaryStatus}}
      <div
        class={{dConcatClass
          "workflows-tests-manager__summary"
          (concat "--" this.summaryStatus)
        }}
        role="status"
      >
        <span class="workflows-tests-manager__summary-main">
          {{dIcon
            (if (eq this.summaryStatus "failed") "circle-xmark" "circle-check")
          }}
          {{this.summaryText}}
        </span>
        {{#if this.summary.notRun}}
          <span class="workflows-tests-manager__summary-meta">
            {{i18n
              "discourse_workflows.tests.summary.not_run"
              count=this.summary.notRun
            }}
          </span>
        {{/if}}
      </div>
    {{/if}}

    <AdminTable
      class="workflows-tests-manager"
      @canLoadMore={{false}}
      @isLoading={{not this.store.loaded}}
      @itemKey="id"
      @items={{this.store.tests}}
    >
      <:empty>
        <EmptyState
          @buttonIcon="list"
          @buttonLabel="discourse_workflows.tests.preview.go_to_executions"
          @description={{i18n "discourse_workflows.tests.empty_description"}}
          @emoji="test_tube"
          @onAction={{this.goToExecutions}}
          @title={{i18n "discourse_workflows.tests.empty_title"}}
        />
      </:empty>
      <:head>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.tests.table.name"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.tests.table.checks"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.tests.table.result"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.tests.table.last_run"
          }}</th>
        <th class="d-table__header-cell"></th>
      </:head>
      <:row as |test|>
        <td class="d-table__cell --overview">
          <LinkTo
            class="workflows-tests-manager__name"
            @models={{array @workflow.id test.id}}
            @route="adminPlugins.show.discourse-workflows.show.workflow-tests.show"
          >
            {{test.name}}
          </LinkTo>
          <div class="workflows-tests-manager__meta">
            <span>
              {{i18n
                "discourse_workflows.tests.table.input_from"
                id=test.source_execution_id
              }}
            </span>
            {{#if test.steps_needing_response.length}}
              <span class="workflows-tests-manager__needs-response">
                {{i18n
                  "discourse_workflows.tests.table.needs_response"
                  count=test.steps_needing_response.length
                }}
              </span>
            {{else if test.captured_at}}
              <span>
                {{i18n "discourse_workflows.tests.table.captured_on"}}
                {{dFormatDate test.captured_at format="medium"}}
              </span>
            {{/if}}
          </div>
          {{#if test.reason}}
            <div
              class={{dConcatClass
                "workflows-tests-manager__reason"
                (if (eq test.state "could_not_run") "--could-not-run")
              }}
            >
              {{dIcon "triangle-exclamation"}}
              {{test.reason}}
            </div>
          {{/if}}
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.tests.table.checks"}}
          </div>
          {{i18n
            "discourse_workflows.tests.table.checks_count"
            count=test.checks_count
          }}
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.tests.table.result"}}
          </div>
          <StatusBadge @status={{test.state}} />
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.tests.table.last_run"}}
          </div>
          {{#if test.last_run_at}}
            {{dFormatDate test.last_run_at format="medium" leaveAgo="true"}}
          {{else}}
            {{i18n "discourse_workflows.tests.table.never_run"}}
          {{/if}}
        </td>
        <td class="d-table__cell --controls">
          <div class="d-table__cell-actions">
            <DButton
              class="btn-default btn-small workflows-tests-manager__run"
              @action={{fn this.runOne test}}
              @disabled={{this.store.running}}
              @icon="play"
              @label="discourse_workflows.tests.run"
            />
            <DButton
              class="btn-default btn-small workflows-tests-manager__delete"
              @action={{fn this.deleteTest test}}
              @icon="trash-can"
              @title="discourse_workflows.tests.delete"
            />
          </div>
        </td>
      </:row>
    </AdminTable>
  </template>
}
