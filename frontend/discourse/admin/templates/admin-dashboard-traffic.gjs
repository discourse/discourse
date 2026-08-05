import DashboardDateRange from "discourse/admin/components/dashboard/date-range";
import SiteTrafficDetail from "discourse/admin/components/dashboard/site-traffic-detail";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="site-traffic-detail-page">
    <DPageHeader
      @titleLabel={{i18n "admin.dashboard.site_traffic.details.title"}}
      @hideTabs={{true}}
      @collapseActionsOnMobile={{false}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin"
          @label={{i18n "admin.dashboard.title"}}
        />
        <DBreadcrumbsItem
          @path="/admin/dashboard/traffic"
          @label={{i18n "admin.dashboard.site_traffic.details.title"}}
        />
      </:breadcrumbs>

      <:actions>
        <div data-test-site-traffic-date-range>
          <DashboardDateRange
            @period={{@controller.period}}
            @startDate={{@controller.startDate}}
            @endDate={{@controller.endDate}}
            @setPeriod={{@controller.setPeriod}}
            @setCustomDateRange={{@controller.setCustomDateRange}}
          />
        </div>
      </:actions>
    </DPageHeader>

    <SiteTrafficDetail
      @startDate={{@controller.start_date}}
      @endDate={{@controller.end_date}}
    />
  </div>
</template>
