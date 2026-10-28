import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import WorkflowPublishState from "../../lib/workflows/publish-state.js";
import { requestAutoRun } from "../../lib/workflows/workflow-tests-store.js";

export default class PublishBanner extends Component {
  @service dialog;
  @service router;
  @service siteSettings;

  #publishState = new WorkflowPublishState({
    workflow: this.args.workflow,
    dialog: this.dialog,
    onDiscard: this.args.onDiscard,
  });

  get showBanner() {
    return this.#publishState.visible;
  }

  get showDiscardButton() {
    return this.#publishState.showDiscardButton;
  }

  get testsSummary() {
    const summary = this.args.workflow.tests_summary;
    if (!this.siteSettings.discourse_workflows_tests_enabled || !summary) {
      return null;
    }
    if (!summary.total) {
      return {
        status: "none",
        text: i18n("discourse_workflows.tests.banner.none"),
      };
    }
    if (summary.failed > 0) {
      return {
        status: "failed",
        text: i18n("discourse_workflows.tests.banner.failing", {
          count: summary.failed,
        }),
      };
    }
    if (summary.could_not_run > 0) {
      return {
        status: "failed",
        text: i18n("discourse_workflows.tests.banner.could_not_run", {
          count: summary.could_not_run,
        }),
      };
    }
    const notRun = summary.not_run + summary.run_again + summary.running;
    if (notRun > 0) {
      return {
        status: "not_run",
        text: i18n("discourse_workflows.tests.banner.not_run", {
          count: notRun,
        }),
      };
    }
    return {
      status: "passed",
      text: i18n("discourse_workflows.tests.banner.passing", {
        count: summary.total,
      }),
    };
  }

  @action
  async runAllTests() {
    requestAutoRun(this.args.workflow.id);
    this.router.transitionTo(
      "adminPlugins.show.discourse-workflows.show.workflow-tests.index",
      this.args.workflow.id
    );
  }

  @action
  async publish() {
    await this.#publishState.publish();
  }

  @action
  async discard() {
    await this.#publishState.discard();
  }

  <template>
    {{#if this.showBanner}}
      <div class="workflows-publish-banner">
        <span class="workflows-publish-banner__body" role="status">
          <span class="workflows-publish-banner__icon">
            {{dIcon "triangle-exclamation"}}
          </span>
          <span class="workflows-publish-banner__text">
            <span class="workflows-publish-banner__title">
              {{i18n "discourse_workflows.unpublished_changes_message"}}
            </span>
            <span class="workflows-publish-banner__detail">
              {{i18n "discourse_workflows.unpublished_changes_message_detail"}}
            </span>
            {{#if this.testsSummary}}
              <span
                class="workflows-publish-banner__tests --{{this.testsSummary.status}}"
              >
                {{dIcon
                  (if
                    (eq this.testsSummary.status "failed")
                    "circle-xmark"
                    (if
                      (eq this.testsSummary.status "passed")
                      "circle-check"
                      (if
                        (eq this.testsSummary.status "not_run")
                        "arrow-rotate-left"
                        "circle"
                      )
                    )
                  )
                }}
                {{this.testsSummary.text}}
                {{#unless (eq this.testsSummary.status "none")}}
                  <DButton
                    class="btn-transparent btn-small workflows-publish-banner__tests-link"
                    @action={{this.runAllTests}}
                    @label="discourse_workflows.tests.banner.run_all"
                  />
                {{/unless}}
                <DButton
                  class="btn-transparent btn-small workflows-publish-banner__tests-link"
                  @label="discourse_workflows.tests.banner.view"
                  @route="adminPlugins.show.discourse-workflows.show.workflow-tests.index"
                  @routeModels={{array @workflow.id}}
                />
              </span>
            {{/if}}
          </span>
        </span>

        <span class="workflows-publish-banner__actions">
          <DButton
            class="btn-primary btn-small workflows-publish-banner__btn"
            @action={{this.publish}}
            @translatedLabel={{i18n "discourse_workflows.publish"}}
          />

          {{#if this.showDiscardButton}}
            <DButton
              class="btn-default btn-small workflows-publish-banner__btn"
              @action={{this.discard}}
              @translatedLabel={{i18n "discourse_workflows.discard_changes"}}
            />
          {{/if}}
        </span>
      </div>
    {{/if}}
  </template>
}
