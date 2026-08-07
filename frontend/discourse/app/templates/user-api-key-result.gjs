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
        @action={{@controller.copy}}
        @translatedLabel={{@controller.buttonLabel}}
        id="copy-api-key-btn"
        class="btn-primary"
      />
    </div>
  </div>
</template>
