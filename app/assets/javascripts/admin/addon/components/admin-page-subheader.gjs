import { hash } from "@ember/helper";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";

const AdminPageSubheader = <template>
  <div class="admin-page-subheader">
    <div class="admin-page-subheader__title-row">
      <h3 class="admin-page-subheader__title">{{i18n @titleLabel}}</h3>
      <div class="admin-page-subheader__actions">
        {{yield
          (hash
            Primary=(component
              DButton class=(concatClass "btn-primary btn-small" @primaryClass)
            )
            Danger=(component
              DButton class=(concatClass "btn-danger btn-small" @dangerClass)
            )
            Default=(component
              DButton class=(concatClass "btn-default btn-small" @defaultClass)
            )
          )
          to="actions"
        }}
      </div>
    </div>
  </div>
</template>;

export default AdminPageSubheader;
