import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import DsaModerationDetails from "discourse/components/dsa-moderation-details";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const Body = <template>
  {{#if @flow.enabled}}
    {{#if @flow.hasActionDetails}}
      <ol
        aria-label={{i18n "review.moderation_steps.label"}}
        class="dsa-moderation-steps"
        {{didUpdate @flow.focusCurrentStep @flow.classificationStep}}
      >
        <li
          aria-current={{if @flow.showContinue "step"}}
          class={{if @flow.showContinue "--current"}}
          tabindex="-1"
        >{{i18n "review.moderation_steps.action"}}</li>
        <li
          aria-current={{unless @flow.showContinue "step"}}
          class={{unless @flow.showContinue "--current"}}
          tabindex="-1"
        >
          {{dIcon "angle-right"}}
          {{i18n "dsa_statements.title"}}
        </li>
      </ol>
      <div hidden={{not @flow.showContinue}}>{{yield}}</div>
    {{/if}}
    <div hidden={{@flow.showContinue}}>
      <DsaModerationDetails
        @formId={{@flow.formId}}
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
      @disabled={{@disabled}}
      @form={{if @flow.enabled @flow.formId}}
      @icon={{@submitIcon}}
      @isLoading={{@isLoading}}
      @translatedLabel={{@submitLabel}}
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

  formId = `dsa-moderation-${guidFor(this)}`;

  get enabled() {
    return Boolean(this.args.options);
  }

  get hasActionDetails() {
    return this.args.hasActionDetails !== false;
  }

  get options() {
    return this.args.options;
  }

  get showContinue() {
    return this.enabled && this.hasActionDetails && !this.classificationStep;
  }

  get showBack() {
    return this.enabled && this.hasActionDetails && this.classificationStep;
  }

  @action
  back() {
    this.classificationStep = false;
  }

  @action
  classify(classification) {
    return this.args.onSubmit({ dsa_classification: { ...classification } });
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
  submit() {
    return this.args.onSubmit();
  }

  <template>
    {{yield
      (hash Body=(component Body flow=this) Footer=(component Footer flow=this))
    }}
  </template>
}
