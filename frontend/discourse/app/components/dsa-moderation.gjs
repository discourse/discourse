import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { trustHTML } from "@ember/template";
import DsaModerationDetails from "discourse/components/dsa-moderation-details";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { applyValueTransformer } from "discourse/lib/transformer";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const Help = <template>
  <DTooltip
    aria-label={{i18n "dsa_statements.help_title"}}
    class="dsa-moderation-help"
    tabindex="0"
    ...attributes
    @icon="circle-question"
    @interactive={{true}}
  >
    <:content>
      <div>{{trustHTML (i18n "dsa_statements.help")}}</div>
    </:content>
  </DTooltip>
</template>;

const Steps = <template>
  {{#if @flow.nextStepLabel}}
    <ol
      aria-label={{i18n "review.moderation_steps.label"}}
      class="dsa-moderation-steps"
    >
      <li aria-current="step" class="--current">
        {{i18n "dsa_statements.title"}}
        <Help />
      </li>
      <li>
        {{dIcon "angle-right"}}
        {{@flow.nextStepLabel}}
      </li>
    </ol>
  {{else if (and @flow.enabled @flow.hasActionDetails)}}
    <ol
      aria-label={{i18n "review.moderation_steps.label"}}
      class="dsa-moderation-steps"
      {{didUpdate @flow.focusCurrentStep @flow.classificationStep}}
    >
      <li
        aria-current={{if @flow.showContinue "step"}}
        class={{if @flow.showContinue "--current"}}
        tabindex="-1"
      >
        {{#if @flow.showBack}}
          <DButton
            class="btn-transparent dsa-moderation-steps__back"
            @action={{@flow.back}}
            @disabled={{@disabled}}
            @translatedLabel={{@flow.actionStepLabel}}
          />
        {{else}}
          {{@flow.actionStepLabel}}
        {{/if}}
      </li>
      <li
        aria-current={{unless @flow.showContinue "step"}}
        class={{unless @flow.showContinue "--current"}}
        tabindex="-1"
      >
        {{dIcon "angle-right"}}
        {{i18n "dsa_statements.title"}}
        <Help />
      </li>
    </ol>
  {{/if}}
</template>;

const Body = <template>
  {{#if @flow.enabled}}
    {{#if @flow.hasActionDetails}}
      <div hidden={{not @flow.showContinue}}>{{yield}}</div>
    {{/if}}
    <div hidden={{@flow.showContinue}}>
      <DsaModerationDetails
        @formId={{@flow.formId}}
        @onRegisterApi={{@flow.registerFormApi}}
        @onSubmit={{@flow.classify}}
        @options={{@flow.options}}
      />
    </div>
  {{else}}
    {{yield}}
  {{/if}}
</template>;

const Footer = <template>
  {{#if @flow.showContinue}}
    <DButton
      class="btn-primary"
      @action={{@flow.continue}}
      @disabled={{@disabled}}
      @label="continue"
    />
  {{else}}
    <DButton
      class={{@submitClass}}
      type={{if @flow.enabled "submit" "button"}}
      @action={{unless @flow.enabled @flow.submit}}
      @disabled={{or @disabled @flow.suggestionLoading}}
      @form={{if @flow.enabled @flow.formId}}
      @icon={{@submitIcon}}
      @isLoading={{@isLoading}}
      @translatedLabel={{@submitLabel}}
    />
  {{/if}}
  {{#if @flow.suggestionButton}}
    <@flow.suggestionButton
      @disabled={{@disabled}}
      @getForm={{@flow.getFormApi}}
      @loading={{@flow.suggestionLoading}}
      @onLoadingChange={{@flow.setSuggestionLoading}}
      @reviewableId={{@flow.reviewableId}}
    />
  {{/if}}
  {{#if @flow.showBack}}
    <DButton
      class="btn-flat"
      @action={{@flow.back}}
      @disabled={{@isLoading}}
      @label="back_button"
    />
  {{else if @cancel}}
    <DButton
      class="btn-flat d-modal-cancel"
      @action={{@cancel}}
      @disabled={{@cancelDisabled}}
      @label="cancel"
    />
  {{/if}}
</template>;

export default class DsaModeration extends Component {
  @tracked classificationStep = false;
  @tracked suggestionLoading = false;

  formId = `dsa-moderation-${guidFor(this)}`;
  #formApi;

  get actionStepLabel() {
    return this.args.actionStepLabel ?? i18n("review.moderation_steps.action");
  }

  get enabled() {
    return Boolean(this.args.options);
  }

  get hasActionDetails() {
    return this.args.hasActionDetails !== false;
  }

  get nextStepLabel() {
    return this.args.nextStepLabel;
  }

  get options() {
    return this.args.options;
  }

  get reviewableId() {
    return this.args.reviewableId;
  }

  get suggestionButton() {
    if (this.enabled && !this.showContinue && this.reviewableId) {
      return applyValueTransformer("dsa-classification-suggestion", null);
    }
  }

  get showTitleHelp() {
    return this.enabled && !this.hasActionDetails && !this.nextStepLabel;
  }

  get showContinue() {
    return this.enabled && this.hasActionDetails && !this.classificationStep;
  }

  get showBack() {
    return this.enabled && this.hasActionDetails && this.classificationStep;
  }

  @action
  getFormApi() {
    return this.#formApi;
  }

  @action
  registerFormApi(formApi) {
    this.#formApi = formApi;
  }

  @action
  back() {
    this.suggestionLoading = false;
    this.classificationStep = false;
  }

  @action
  classify(classification) {
    if (!this.suggestionLoading) {
      return this.args.onSubmit({ dsa_classification: { ...classification } });
    }
  }

  @action
  continue() {
    this.classificationStep = true;
  }

  @action
  focusCurrentStep(element) {
    element.querySelector('[aria-current="step"]').focus();
  }

  @action
  setSuggestionLoading(loading) {
    this.suggestionLoading = loading;
  }

  @action
  submit() {
    return this.args.onSubmit();
  }

  <template>
    {{yield
      (hash
        Help=Help
        showTitleHelp=this.showTitleHelp
        Body=(component Body flow=this)
        Footer=(component Footer flow=this)
        Steps=(component Steps flow=this)
      )
    }}
  </template>
}
