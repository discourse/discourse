import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import i18n from "discourse-common/helpers/i18n";
import {
  DangerButton,
  DefaultButton,
  PrimaryButton,
} from "admin/components/admin-page-action-button";

const AdminPageSubheader = <template>
  <div class="admin-page-subheader">
    <div class="admin-page-subheader__title-row">
      <h3 class="admin-page-subheader__title">{{i18n @titleLabel}}</h3>
      <div class="admin-page-subheader__actions">
        {{yield
          (hash Primary=PrimaryButton Default=DefaultButton Danger=DangerButton)
          to="actions"
        }}
      </div>

      {{#if @descriptionLabel}}
        <p class="admin-page-header__description">
          {{i18n @descriptionLabel}}
          {{#if @learnMoreUrl}}
            {{htmlSafe (i18n "learn_more_with_link" url=@learnMoreUrl)}}
          {{/if}}
        </p>
      {{/if}}
    </div>
  </div>
</template>;

export default AdminPageSubheader;
