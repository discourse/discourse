import { concat } from "@ember/helper";
import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @area={{@model.wildcard}}
    @filter={{@controller.filter}}
    @path={{concat "/admin/config/login-and-authentication/" @model.wildcard}}
    @showBreadcrumb={{false}}
  />
</template>
