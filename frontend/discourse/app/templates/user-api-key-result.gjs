import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import DButton from "discourse/ui-kit/d-button";

export default <template>
  {{hideApplicationSidebar}}
  {{hideApplicationFooter}}

  <div class="authorize-api-key">
    <p>{{@model.instructions}}</p>
    <div class="user-api-key-display">
      <code id="user-api-key-payload">{{@model.payload}}</code>
    </div>
    <div>
      <DButton
        class="btn-primary"
        id="copy-api-key-btn"
        @action={{@controller.copy}}
        @translatedLabel={{@controller.buttonLabel}}
      />
    </div>
  </div>
</template>
