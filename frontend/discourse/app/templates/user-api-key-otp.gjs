import { on } from "@ember/modifier";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default <template>
  {{hideApplicationSidebar}}
  {{hideApplicationFooter}}

  <div class="authorize-api-key">
    <h1>
      {{i18n
        "user_api_key.otp_description"
        application_name=@model.application_name
      }}
    </h1>

    {{#if @controller.error}}
      <p class="error-message">{{@controller.error}}</p>
    {{/if}}

    <form {{on "submit" @controller.authorize}}>
      <DButton
        @isLoading={{@controller.isLoading}}
        @action={{@controller.authorize}}
        @label="user_api_key.authorize"
        type="submit"
        class="btn-primary"
      />
    </form>
  </div>
</template>
