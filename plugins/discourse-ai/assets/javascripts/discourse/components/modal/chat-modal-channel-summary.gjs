import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import DConditionalLoadingSection from "discourse/ui-kit/d-conditional-loading-section";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";
import {
  isAiCreditLimitError,
  popupAiCreditLimitError,
} from "../../lib/ai-errors";

export default class ChatModalChannelSummary extends Component {
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
  async summarize(since) {
    this.sinceHours = since;
    this.loading = true;

    if (this.availableSummaries[since]) {
      this.summary = this.availableSummaries[since];
      this.loading = false;
      return;
    }

    try {
      const data = await ajax(
        `/discourse-ai/summarization/channels/${this.channelId}.json`,
        {
          type: "POST",
          data: {
            since,
          },
        }
      );
      this.availableSummaries[this.sinceHours] = data.summary;
      this.summary = this.availableSummaries[this.sinceHours];
    } catch (error) {
      if (isAiCreditLimitError(error)) {
        popupAiCreditLimitError(error);
      } else {
        popupAjaxError(error);
      }
    } finally {
      this.loading = false;
    }
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
        <DConditionalLoadingSection @isLoading={{this.loading}}>
          <p class="summary-area">{{this.summary}}</p>
        </DConditionalLoadingSection>
      </:body>
      <:footer>
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
