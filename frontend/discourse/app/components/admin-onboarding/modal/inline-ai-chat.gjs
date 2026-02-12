import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

export default class InlineAiChat extends Component {
  get personaName() {
    return this.args.model?.personaName || "AI Assistant";
  }

  <template>
    <DModal
      class="inline-ai-chat-modal"
      @title={{this.personaName}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="inline-ai-chat__content">
          <p class="inline-ai-chat__message">
            {{i18n
              "admin_onboarding_banner.start_posting.ai_chat_mock_message"
            }}
          </p>
        </div>
      </:body>
      <:footer>
        <DButton
          @label="cancel"
          @action={{@closeModal}}
          class="btn-transparent cancel-button"
        />
      </:footer>
    </DModal>
  </template>
}
