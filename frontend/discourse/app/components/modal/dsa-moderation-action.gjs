import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DsaModeration from "discourse/components/dsa-moderation";
import { extractError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class DsaModerationAction extends Component {
  @tracked flash;
  @tracked saving = false;

  get buttonClass() {
    return this.confirmationMessage && !this.#editing
      ? "btn-danger"
      : "btn-primary";
  }

  get buttonLabel() {
    if (this.#editing) {
      return i18n("review.continue_to_editor");
    }
    return this.confirmationMessage
      ? this.args.model.action.label
      : i18n("dsa_statements.save");
  }

  get confirmationMessage() {
    return this.args.model.action.confirm_message;
  }

  get confirmationTitle() {
    return this.args.model.action.confirm_title;
  }

  get nextStepLabel() {
    return this.#editing ? this.args.model.action.label : null;
  }

  get title() {
    if (this.confirmationMessage) {
      return this.confirmationTitle ?? this.args.model.action.label;
    }
    return this.#editing
      ? this.args.model.action.label
      : i18n("dsa_statements.title");
  }

  get #editing() {
    return this.args.model.action.client_action === "edit";
  }

  @action
  async submit(data) {
    if (this.saving) {
      return;
    }
    this.saving = true;
    this.flash = null;
    try {
      await this.args.model.perform(data);
      this.args.closeModal();
    } catch (error) {
      this.flash = extractError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DsaModeration
      @hasActionDetails={{false}}
      @nextStepLabel={{this.nextStepLabel}}
      @onSubmit={{this.submit}}
      @options={{@model.options}}
      @reviewableId={{@model.reviewable.id}}
      as |flow|
    >
      <DModal
        class="dsa-moderation-action"
        ...attributes
        @closeModal={{@closeModal}}
        @dismissable={{not this.saving}}
        @flash={{this.flash}}
        @title={{this.title}}
      >
        <:headerBelowTitle>
          {{#if (and flow.showTitleHelp (not this.confirmationMessage))}}
            <flow.Help class="dsa-moderation-title-help" />
          {{/if}}
        </:headerBelowTitle>
        <:belowHeader>
          <flow.Steps @disabled={{this.saving}} />
        </:belowHeader>
        <:body>
          {{#if this.confirmationMessage}}
            {{#unless this.confirmationTitle}}
              <p>{{this.confirmationMessage}}</p>
            {{/unless}}
            <div class="dsa-moderation-action__classification">
              <h2>{{i18n "dsa_statements.title"}}</h2>
              <flow.Help />
            </div>
          {{/if}}
          <flow.Body />
        </:body>
        <:footer>
          <flow.Footer
            @cancel={{if this.confirmationMessage @closeModal}}
            @cancelDisabled={{this.saving}}
            @disabled={{this.saving}}
            @isLoading={{this.saving}}
            @requireCompleteClassification={{this.confirmationMessage}}
            @submitClass={{this.buttonClass}}
            @submitLabel={{this.buttonLabel}}
          />
        </:footer>
      </DModal>
    </DsaModeration>
  </template>
}
