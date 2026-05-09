import DashboardDateRange from "discourse/admin/components/dashboard/date-range";
import DashboardEngagement from "discourse/admin/components/dashboard/engagement";
import DashboardHighlights from "discourse/admin/components/dashboard/highlights";
import DashboardReports from "discourse/admin/components/dashboard/reports";
import DashboardTraffic from "discourse/admin/components/dashboard/traffic";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DMenu from "discourse/float-kit/components/d-menu";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const sections = [
  {
    id: "highlights",
    label: "admin.dashboard.sections.highlights.title",
    visible: true,
  },
  {
    id: "reports",
    label: "admin.dashboard.sections.reports.title",
    visible: true,
  },
  {
    id: "traffic",
    label: "admin.dashboard.sections.traffic.title",
    visible: true,
  },
  {
    id: "engagement",
    label: "admin.dashboard.sections.engagement.title",
    visible: true,
  },
];

const RedesignedAdminDashboard = <template>
  <div class="db-toolbar">
    <h1>Dashboard</h1>

    <div class="db-toolbar__actions">
      <DashboardDateRange
        @period={{@period}}
        @startDate={{@startDate}}
        @endDate={{@endDate}}
        @setPeriod={{@setPeriod}}
        @setCustomDateRange={{@setCustomDateRange}}
      />

      <DMenu
        @identifier="db-customise"
        @icon="gear"
        @label="Customise"
        @triggerClass="btn-default"
        @modalForMobile={{true}}
      >
        <:content>
          <div class="db-customise">
            <ul class="db-customise__list">
              {{#each sections as |s|}}
                <li class="db-customise__row">
                  <span class="db-customise__drag-handle">{{icon
                      "grip-vertical"
                    }}</span>
                  <span class="db-customise__section-name">{{i18n
                      s.label
                    }}</span>
                  <DToggleSwitch @state={{s.visible}} />
                </li>
              {{/each}}
            </ul>
          </div>
        </:content>
      </DMenu>
    </div>
  </div>

  <div class="db-main">
    <DashboardHighlights @startDate={{@startDate}} @endDate={{@endDate}} />
    <DashboardReports @startDate={{@startDate}} @endDate={{@endDate}} />
    <DashboardTraffic @startDate={{@startDate}} @endDate={{@endDate}} />
    <DashboardEngagement @startDate={{@startDate}} @endDate={{@endDate}} />
  </div>
</template>;

export default RedesignedAdminDashboard;
