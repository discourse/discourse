import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { schedule } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import emoji from "discourse/helpers/emoji";
import { i18n } from "discourse-i18n";
import WizardField from "./wizard-field";

export default class WizardStepComponent extends Component {
  @tracked saving = false;

  get wizard() {
    return this.args.wizard;
  }

  get step() {
    return this.args.step;
  }

  get id() {
    return this.step.id;
  }

  // We don't want to show the step counter for optional steps after
  // the "Ready" step.
  get showStepCounter() {
    return this.args.step.displayIndex < 5;
  }

  /**
   * Step        Back Button?     Primary Action      Secondary Action
   * ------------------------------------------------------------------
   * First            No               Next                  N/A
   * ------------------------------------------------------------------
   * ...             Yes               Next                  N/A
   * ------------------------------------------------------------------
   * Ready           Yes              Jump In          Configure More
   * ------------------------------------------------------------------
   * ...             Yes               Next              Exit Setup
   * ------------------------------------------------------------------
   * Last            Yes              Jump In                N/A
   * ------------------------------------------------------------------
   *
   * Back Button: without saving, go back to the last page
   * Next Button: save, and if successful, go to the next page
   * Configure More: re-skinned next button
   * Exit Setup: without saving, go to the home page ("finish")
   * Jump In: on the "ready" page, it exits the setup ("finish"), on the
   * last page, it saves, and if successful, go to the home page
   */
  get isFinalStep() {
    return this.step.displayIndex === this.wizard.steps.length;
  }

  get showBackButton() {
    return this.step.index > 0;
  }

  get showFinishButton() {
    const ready = this.wizard.findStep("ready");
    const isReady = ready && this.step.index > ready.index;
    return isReady && !this.isFinalStep;
  }

  get showConfigureMore() {
    return this.id === "ready";
  }

  get showJumpInButton() {
    return this.id === "ready" || this.isFinalStep;
  }

  get includeSidebar() {
    return !!this.step.fields.find((f) => f.showInSidebar);
  }

  @action
  stepChanged() {
    this.saving = false;
    this.autoFocus();
  }

  @action
  onKeyUp(event) {
    if (event.key === "Enter") {
      if (this.showJumpInButton) {
        this.jumpIn();
      } else {
        this.nextStep();
      }
    }
  }

  @action
  autoFocus() {
    schedule("afterRender", () => {
      const firstInvalidElement = document.querySelector(
        ".wizard-container__input.invalid:nth-of-type(1) .wizard-focusable"
      );

      if (firstInvalidElement) {
        return firstInvalidElement.focus();
      }

      document.querySelector(".wizard-focusable:nth-of-type(1)")?.focus();
    });
  }

  async advance() {
    try {
      this.saving = true;
      const response = await this.step.save();
      this.args.goNext(response);
    } finally {
      this.saving = false;
    }
  }

  @action
  finish(event) {
    event?.preventDefault();

    if (this.saving) {
      return;
    }

    this.args.goHome();
  }

  @action
  jumpIn(event) {
    event?.preventDefault();

    if (this.saving) {
      return;
    }

    if (this.id === "ready") {
      this.finish();
    } else {
      this.nextStep();
    }
  }

  @action
  backStep(event) {
    event?.preventDefault();

    if (this.saving) {
      return;
    }

    this.args.goBack();
  }

  @action
  nextStep(event) {
    event?.preventDefault();

    if (this.saving) {
      return;
    }

    if (this.step.validate()) {
      this.advance();
    } else {
      this.autoFocus();
    }
  }

  <template>
    <div
      class="wizard-container__step {{@step.id}}"
      {{didInsert this.autoFocus}}
      {{didUpdate this.stepChanged @step.id}}
    >
      {{#if this.showStepCounter}}
        <div class="wizard-container__step-counter">
          <span class="wizard-container__step-text">
            {{i18n "wizard.step-text"}}
          </span>
          <span class="wizard-container__step-count">
            {{i18n
              "wizard.step"
              current=@step.displayIndex
              total=@wizard.totalSteps
            }}
          </span>
        </div>
      {{/if}}

      <div class="wizard-container">
        <div class="wizard-container__step-contents">
          <div class="wizard-container__step-header">
            {{#if @step.emoji}}
              <div class="wizard-container__step-header--emoji">
                {{emoji @step.emoji}}
              </div>
            {{/if}}
            {{#if @step.title}}
              <h1 class="wizard-container__step-title">{{@step.title}}</h1>
              {{#if @step.description}}
                <p class="wizard-container__step-description">
                  {{htmlSafe @step.description}}
                </p>
              {{/if}}
            {{/if}}
          </div>

          <div class="wizard-container__step-container">
            {{#if @step.fields}}
              <div class="wizard-container__step-form">
                {{#if this.includeSidebar}}
                  <div class="wizard-container__sidebar">
                    {{#each @step.fields as |field|}}
                      {{#if field.showInSidebar}}
                        <WizardField
                          @field={{field}}
                          @step={{@step}}
                          @wizard={{@wizard}}
                        />
                      {{/if}}
                    {{/each}}
                  </div>
                {{/if}}
                <div class="wizard-container__fields">
                  {{#each @step.fields as |field|}}
                    {{#unless field.showInSidebar}}
                      <WizardField
                        @field={{field}}
                        @step={{@step}}
                        @wizard={{@wizard}}
                      />
                    {{/unless}}
                  {{/each}}
                </div>
              </div>
            {{/if}}
          </div>
        </div>

        <div class="wizard-container__step-footer">
          <div class="wizard-container__buttons-left">
            {{#if this.showBackButton}}
              <button
                {{on "click" this.backStep}}
                disabled={{this.saving}}
                type="button"
                class="wizard-container__button back"
              >
                {{i18n "wizard.back"}}
              </button>
            {{/if}}
          </div>

          <div class="wizard-container__buttons-right">
            {{#if this.showFinishButton}}
              <button
                {{on "click" this.finish}}
                disabled={{this.saving}}
                type="button"
                class="wizard-container__button finish"
              >
                {{i18n "wizard.finish"}}
              </button>
            {{else if this.showConfigureMore}}
              <button
                {{on "click" this.nextStep}}
                disabled={{this.saving}}
                type="button"
                class="wizard-container__button configure-more"
              >
                {{i18n "wizard.configure_more"}}
              </button>
            {{/if}}

            {{#if this.showJumpInButton}}
              <button
                {{on "click" this.jumpIn}}
                disabled={{this.saving}}
                type="button"
                class="wizard-container__button primary jump-in"
              >
                {{i18n "wizard.jump_in"}}
              </button>
            {{else}}
              <button
                {{on "click" this.nextStep}}
                disabled={{this.saving}}
                type="button"
                class="wizard-container__button primary next"
              >
                {{i18n "wizard.next"}}
              </button>
            {{/if}}

          </div>

        </div>
      </div>
    </div>
  </template>
}
