import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import DashboardEngagement from "discourse/admin/components/dashboard/engagement";
import DashboardHighlights from "discourse/admin/components/dashboard/highlights";
import DashboardReports from "discourse/admin/components/dashboard/reports";
import DashboardTraffic from "discourse/admin/components/dashboard/traffic";
import DSegmentedControl from "discourse/components/d-segmented-control";
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

export default class RedesignedAdminDashboard extends Component {
  // eslint-disable-next-line discourse/no-unnecessary-tracked
  @tracked startDate = moment().subtract(30, "days").toDate();
  // eslint-disable-next-line discourse/no-unnecessary-tracked
  @tracked endDate = moment().toDate();

  <template>
    <div class="db-toolbar">
      <h1>Dashboard</h1>

      <div class="db-toolbar__actions">
        <DSegmentedControl
          @name="period"
          @value="month"
          @items={{array
            (hash value="day" label="Day")
            (hash value="week" label="Week")
            (hash value="month" label="Month")
            (hash value="custom" label="Custom")
          }}
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
      <DashboardHighlights
        @startDate={{this.startDate}}
        @endDate={{this.endDate}}
      />
      <DashboardReports
        @startDate={{this.startDate}}
        @endDate={{this.endDate}}
      />
      <DashboardTraffic
        @startDate={{this.startDate}}
        @endDate={{this.endDate}}
      />
      <DashboardEngagement
        @startDate={{this.startDate}}
        @endDate={{this.endDate}}
      />
    </div>
  </template>
}
