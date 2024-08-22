import { hash } from "@ember/helper";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import {
  DangerButton,
  DefaultButton,
  PrimaryButton,
} from "admin/components/admin-page-action-button";

const AdminSectionLandingItem = <template>
  <div class="admin-section-landing-item" ...attributes>
    {{#if @imageUrl}}
      <img class="admin-section-landing-item__image" src={{@imageUrl}} />
    {{/if}}
    <div class="admin-section-landing-item__icon">
      {{dIcon @icon}}
    </div>
    <div class="admin-section-landing-item__content">
      <h3 class="admin-section-landing-item__title">{{i18n @titleLabel}}</h3>
      <p class="admin-section-landing-item__description">{{i18n
          @descriptionLabel
        }}</p>
    </div>

    <div class="admin-section-landing-item__buttons">
      {{yield
        (hash Primary=PrimaryButton Default=DefaultButton Danger=DangerButton)
        to="buttons"
      }}
    </div>
  </div>
</template>;

export default AdminSectionLandingItem;
