import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const StartPostingOptions = <template>
  <DModal
    class="start-posting-options-modal"
    @title={{i18n "admin_onboarding_banner.start_posting.choose_option"}}
    @closeModal={{@closeModal}}
  >
    <:body>
      <div class="modal-options">
        {{#each @model.options as |Option|}}
          <Option @closeModal={{@closeModal}} />
        {{/each}}
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
</template>;

export default StartPostingOptions;
