import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DsaStatementClassification from "discourse/components/dsa-statement-classification";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class DsaClassificationModal extends Component {
  @service dialog;

  @tracked saving = false;

  @action
  savingChanged(saving) {
    this.saving = saving;
  }

  @action
  showHelp() {
    this.dialog.alert(i18n("dsa_statements.help"));
  }

  <template>
    <DModal
      class="dsa-classification-modal"
      @closeModal={{@closeModal}}
      @dismissable={{not this.saving}}
      @title={{i18n "dsa_statements.title"}}
    >
      <:headerBelowTitle>
        <DButton
          class="btn-transparent dsa-classification-modal__help"
          @action={{this.showHelp}}
          @icon="circle-question"
          @title="dsa_statements.help_title"
        />
      </:headerBelowTitle>
      <:body>
        <DsaStatementClassification
          @classificationOptions={{@model.classificationOptions}}
          @hideHeading={{true}}
          @onCancel={{@closeModal}}
          @onSavingChange={{this.savingChanged}}
          @reviewable={{@model.reviewable}}
          @showCancel={{true}}
        />
      </:body>
    </DModal>
  </template>
}
