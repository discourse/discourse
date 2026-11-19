import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { trustHTML } from "@ember/template";
import DsaModerationDetails from "discourse/components/dsa-moderation-details";
import PluginOutlet from "discourse/components/plugin-outlet";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import lazyHash from "discourse/helpers/lazy-hash";
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
        @disabled={{@flow.isUpdatingClassification}}
        @fieldHints={{@flow.fieldHints}}
        @formId={{@flow.formId}}
        @onFieldSet={{@flow.editField}}
        @onRegisterApi={{@flow.registerFormApi}}
        @onSubmit={{@flow.classify}}
        @options={{@flow.options}}
        @validate={{@flow.validateClassification}}
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
      @disabled={{or @disabled @flow.isUpdatingClassification}}
      @form={{if @flow.enabled @flow.formId}}
      @icon={{@submitIcon}}
      @isLoading={{@isLoading}}
      @translatedLabel={{@submitLabel}}
    />
  {{/if}}
  {{#if (and @flow.enabled @flow.reviewableId)}}
    <div class="dsa-classification-footer" hidden={{@flow.showContinue}}>
      <PluginOutlet
        @name="dsa-classification-footer"
        @outletArgs={{lazyHash
          disabled=(or @disabled @flow.isUpdatingClassification)
          reviewableId=@flow.reviewableId
          updateClassification=@flow.updateClassification
        }}
      />
    </div>
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
  @tracked fieldHints = {};
  @tracked isUpdatingClassification = false;

  formId = `dsa-moderation-${guidFor(this)}`;
  #setClassification;

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
  registerFormApi({ setProperties }) {
    this.#setClassification = setProperties;
  }

  @action
  back() {
    this.classificationStep = false;
  }

  @action
  classify(classification) {
    if (this.isUpdatingClassification) {
      return;
    }

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

  @action
  validateClassification(_classification, { preventSubmit }) {
    if (this.isUpdatingClassification) {
      preventSubmit();
    }
  }

  @action
  async editField(value, { name, set }) {
    if (this.fieldHints[name]) {
      const hints = { ...this.fieldHints };
      delete hints[name];
      this.fieldHints = hints;
    }
    await set(name, value);
  }

  @action
  async updateClassification(load, hint) {
    if (this.isUpdatingClassification) {
      return;
    }

    this.isUpdatingClassification = true;
    try {
      const { community_rule, category } = await load();
      if (this.isDestroying) {
        return;
      }
      const values = {
        ...(this.options.community_rules.length > 1 &&
          community_rule && { community_rule }),
        ...(category && { category }),
      };
      await this.#setClassification(values);
      const fields = Object.keys(values);
      this.fieldHints = {
        ...this.fieldHints,
        ...Object.fromEntries(fields.map((field) => [field, hint])),
      };
      return fields.length > 0;
    } finally {
      if (!this.isDestroying) {
        this.isUpdatingClassification = false;
      }
    }
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
