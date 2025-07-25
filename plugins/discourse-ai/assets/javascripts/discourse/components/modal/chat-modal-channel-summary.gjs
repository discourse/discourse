import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default class ChatModalChannelSummary extends Component {
  @service chatApi;

  @tracked sinceHours = null;
  @tracked loading = false;
  @tracked summary = null;

  availableSummaries = {};

  sinceOptions = [1, 3, 6, 12, 24, 72, 168].map((hours) => {
    return {
      name: i18n("discourse_ai.summarization.chat.since", { count: hours }),
      value: hours,
    };
  });

  get channelId() {
    return this.args.model.channelId;
  }

  @action
  summarize(since) {
    this.sinceHours = since;
    this.loading = true;

    if (this.availableSummaries[since]) {
      this.summary = this.availableSummaries[since];
      this.loading = false;
      return;
    }

    return ajax(`/discourse-ai/summarization/channels/${this.channelId}.json`, {
      type: "GET",
      data: {
        since,
      },
    })
      .then((data) => {
        this.availableSummaries[this.sinceHours] = data.summary;
        this.summary = this.availableSummaries[this.sinceHours];
      })
      .catch(popupAjaxError)
      .finally(() => (this.loading = false));
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      class="chat-modal-channel-summary"
      @title={{i18n "discourse_ai.summarization.chat.title"}}
    >
      <:body>
        <span>{{i18n "discourse_ai.summarization.chat.description"}}</span>
        <ComboBox
          @value={{this.sinceHours}}
          @content={{this.sinceOptions}}
          @onChange={{this.summarize}}
          @valueProperty="value"
          class="summarization-since"
        />
        <ConditionalLoadingSection @isLoading={{this.loading}}>
          <p class="summary-area">{{this.summary}}</p>
        </ConditionalLoadingSection>
      </:body>
      <:footer>
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
