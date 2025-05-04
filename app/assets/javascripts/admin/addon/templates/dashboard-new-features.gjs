import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";
import DashboardNewFeatures from "admin/components/dashboard-new-features";

export default RouteTemplate(
  <template>
    <ConditionalLoadingSpinner @condition={{@controller.isLoading}}>
      <div class="admin-config-area">
        <h2>{{i18n "admin.dashboard.new_features.title"}}</h2>
        <p>{{htmlSafe (i18n "admin.dashboard.new_features.subtitle")}}</p>
        <DashboardNewFeatures />
      </div>
    </ConditionalLoadingSpinner>
  </template>
);
