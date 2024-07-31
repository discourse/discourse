import { hash } from "@ember/helper";
import i18n from "discourse-common/helpers/i18n";
import AdminPageActionButton from "admin/components/admin-page-action-button";

const AdminPageSubheader = <template>
  <div class="admin-page-subheader">
    <div class="admin-page-subheader__title-row">
      <h3 class="admin-page-subheader__title">{{i18n @titleLabel}}</h3>
      <div class="admin-page-subheader__actions">
        {{yield
          (hash
            Primary=(component
              AdminPageActionButton buttonClasses="btn-primary btn-small"
            )
            Danger=(component
              AdminPageActionButton buttonClasses="btn-danger btn-small"
            )
            Default=(component
              AdminPageActionButton buttonClasses="btn-default btn-small"
            )
          )
          to="actions"
        }}
      </div>
    </div>
  </div>
</template>;

export default AdminPageSubheader;
