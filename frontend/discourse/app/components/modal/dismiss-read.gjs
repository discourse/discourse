import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class DismissRead extends Component {
  @tracked dismissTopics = false;

  <template>
    <DModal
      class="dismiss-read-modal"
      @closeModal={{@closeModal}}
      @title={{i18n @model.title count=@model.count}}
    >
      <:body>
        <p>
          <PreferenceCheckbox
            class="dismiss-read-modal__stop-tracking"
            @checked={{this.dismissTopics}}
            @labelKey="topics.bulk.also_dismiss_topics"
          />
        </p>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          id="dismiss-read-confirm"
          @action={{fn @model.dismissRead this.dismissTopics}}
          @icon="check"
          @label="topics.bulk.dismiss"
        />
      </:footer>
    </DModal>
  </template>
}
