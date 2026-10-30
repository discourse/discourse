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
    return this.hasActionDetails && !this.#editing
      ? "btn-danger"
      : "btn-primary";
  }

  get buttonLabel() {
    if (this.#editing) {
      return i18n("review.continue_to_editor");
    }
    return this.hasActionDetails
      ? this.args.model.action.label
      : i18n("dsa_statements.save");
  }

  get hasActionDetails() {
    return Boolean(this.args.model.action.confirm_message);
  }

  get title() {
    return this.hasActionDetails
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
      @hasActionDetails={{this.hasActionDetails}}
      @onSubmit={{this.submit}}
      @options={{@model.options}}
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
        <:body>
          <flow.Body>
            <p>{{@model.action.confirm_message}}</p>
          </flow.Body>
        </:body>
        <:footer>
          <flow.Footer
            @cancel={{if @model.action.confirm_message @closeModal}}
            @cancelDisabled={{this.saving}}
            @disabled={{this.saving}}
            @isLoading={{this.saving}}
            @submitClass={{this.buttonClass}}
            @submitLabel={{this.buttonLabel}}
          />
        </:footer>
      </DModal>
    </DsaModeration>
  </template>
}
