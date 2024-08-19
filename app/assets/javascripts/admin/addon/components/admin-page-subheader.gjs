import { hash } from "@ember/helper";
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
    </div>
  </div>
</template>;

export default AdminPageSubheader;
