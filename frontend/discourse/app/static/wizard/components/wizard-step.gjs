import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import emoji from "discourse/helpers/emoji";
import getUrl from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import WizardField from "./wizard-field";

export default class WizardStepComponent extends Component {
  @tracked hasError = false;

  get wizard() {
    return this.args.wizard;
  }

  get step() {
    return this.args.step;
  }

  get id() {
    return this.step.id;
  }

  get containerFontClasses() {
    let fontClasses = "";

    if (this.wizard.font) {
      fontClasses += ` wizard-container-body-font-${this.wizard.font.id}`;
    }

    if (this.wizard.headingFont) {
      fontClasses += ` wizard-container-heading-font-${this.wizard.headingFont.id}`;
    }

    return fontClasses;
  }

  @action
  async jumpIn() {
    const valid = await this.step.validate();
    if (!valid) {
      this.hasError = true;
      return;
    }

    const response = await this.step.save();
    if (response && response.success) {
      // We are not using Ember routing here because we always want to reload the app
      // ensure language, site title are properly set.
      document.location = getUrl("/");
    }
  }

  <template>
    <div class="wizard-container__step {{@step.id}}">
      <div class={{concatClass "wizard-container" this.containerFontClasses}}>
        <div class="wizard-container__step-contents">
          <div class="wizard-container__step-header">
            <div class="wizard-container__step-header--emoji">
              {{emoji @step.emoji}}
            </div>
            <h1 class="wizard-container__step-title">{{@step.title}}</h1>
          </div>

          <div class="wizard-container__step-container">
            {{#if @step.fields}}
              <div class="wizard-container__step-form">
                <div class="wizard-container__fields">
                  {{#each @step.fields as |field|}}
                    <WizardField
                      @field={{field}}
                      @step={{@step}}
                      @wizard={{@wizard}}
                    />
                  {{/each}}
                </div>
              </div>
            {{/if}}
          </div>
        </div>

        <div class="wizard-container__step-footer">
          <button
            {{on "click" this.jumpIn}}
            type="button"
            class="wizard-container__button jump-in btn btn-primary"
          >
            {{i18n "wizard.jump_in"}}
          </button>
        </div>
      </div>
    </div>
  </template>
}
