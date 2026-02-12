import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

export default class StartPostingOptions extends Component {
  @action
  async handlePredefinedOptions() {
    this.args.closeModal();
    this.args.model.onSelectPredefined();
  }

  @action
  async handleAiGeneration() {
    this.args.closeModal();
    this.args.model.onSelectAi();
  }

  <template>
    <DModal
      class="start-posting-options-modal"
      @title={{i18n "admin_onboarding_banner.start_posting.choose_option"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <p>
          {{i18n
            "admin_onboarding_banner.start_posting.choose_option_description"
          }}
        </p>
        <div class="modal-options">
          <div class="option predefined-option">
            <h3>{{i18n
                "admin_onboarding_banner.start_posting.predefined_topics"
              }}</h3>
            <p>
              {{i18n
                "admin_onboarding_banner.start_posting.predefined_topics_description"
              }}
            </p>
            <DButton
              @label="admin_onboarding_banner.start_posting.use_predefined"
              @action={{this.handlePredefinedOptions}}
              class="btn-primary"
            />
          </div>
          <div class="option ai-option">
            <h3>{{i18n
                "admin_onboarding_banner.start_posting.ai_generation"
              }}</h3>
            <p>
              {{i18n
                "admin_onboarding_banner.start_posting.ai_generation_description"
              }}
            </p>
            <DButton
              @label="admin_onboarding_banner.start_posting.use_ai"
              @action={{this.handleAiGeneration}}
              class="btn-primary"
            />
          </div>
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
