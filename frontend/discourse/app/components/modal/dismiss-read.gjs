import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import { i18n } from "discourse-i18n";

export default class DismissRead extends Component {
  @tracked dismissTopics = false;

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n @model.title count=@model.count}}
      class="dismiss-read-modal"
    >
      <:body>
        <p>
          <PreferenceCheckbox
            @labelKey="topics.bulk.also_dismiss_topics"
            @checked={{this.dismissTopics}}
            class="dismiss-read-modal__stop-tracking"
          />
        </p>
      </:body>
      <:footer>
        <DButton
          @action={{fn @model.dismissRead this.dismissTopics}}
          @label="topics.bulk.dismiss"
          @icon="check"
          id="dismiss-read-confirm"
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
