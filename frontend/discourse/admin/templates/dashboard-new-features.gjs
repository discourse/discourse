import { trustHTML } from "@ember/template";
import DashboardNewFeatures from "discourse/admin/components/dashboard-new-features";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import { i18n } from "discourse-i18n";

export default <template>
  <DConditionalLoadingSpinner @condition={{@controller.isLoading}}>
    <div class="admin-config-area">
      <h2>{{i18n "admin.dashboard.new_features.title"}}</h2>
      <p>{{trustHTML (i18n "admin.dashboard.new_features.subtitle")}}</p>
      <DashboardNewFeatures />
    </div>
  </DConditionalLoadingSpinner>
</template>
