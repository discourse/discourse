import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DsaModerationDetails from "discourse/components/dsa-moderation-details";
import { extractError } from "discourse/lib/ajax-error";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class DsaModerationAction extends Component {
  @tracked flash;
  @tracked saving = false;

  get titleKey() {
    return `dsa_statements.action.${this.args.model.action.server_action}`;
  }

  @action
  async submit(data) {
    this.saving = true;
    this.flash = null;
    try {
      await this.args.model.perform({ dsa_classification: data });
      this.args.closeModal();
    } catch (error) {
      this.flash = extractError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      class="dsa-moderation-action"
      @closeModal={{@closeModal}}
      @dismissable={{not this.saving}}
      @flash={{this.flash}}
      @title={{i18n this.titleKey}}
    >
      <:body>
        <h3 class="dsa-moderation-action__subheader">{{i18n
            "dsa_statements.title"
          }}</h3>
        <DsaModerationDetails
          @formId="dsa-moderation-action-form"
          @onSubmit={{this.submit}}
          @options={{@model.options}}
        />
      </:body>
      <:footer>
        <DButton
          class="btn-danger"
          type="submit"
          @disabled={{this.saving}}
          @form="dsa-moderation-action-form"
          @isLoading={{this.saving}}
          @label={{this.titleKey}}
        />
        <DButton
          class="btn-flat"
          @action={{@closeModal}}
          @disabled={{this.saving}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
