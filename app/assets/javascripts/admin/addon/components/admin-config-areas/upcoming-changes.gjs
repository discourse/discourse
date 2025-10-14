import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { i18n } from "discourse-i18n";
import UpcomingChangeItem from "admin/components/admin-config-areas/upcoming-change-item";
import AdminFilterControls from "admin/components/admin-filter-controls";

export default class AdminConfigAreasUpcomingChanges extends Component {
  get upcomingChanges() {
    return this.args.upcomingChanges.map((change) => {
      return new TrackedObject(change);
    });
  }

  get dropdownOptions() {
    return [
      {
        label: i18n("admin.upcoming_changes.filter.all"),
        value: "all",
        filterFn: () => true,
      },
      {
        label: i18n("admin.upcoming_changes.filter.enabled"),
        value: "enabled",
        filterFn: (change) => change.value,
      },
      {
        label: i18n("admin.upcoming_changes.filter.disabled"),
        value: "disabled",
        filterFn: (change) => !change.value,
      },
      {
        label: i18n("admin.upcoming_changes.filter.impact_type_feature"),
        value: "feature",
        filterFn: (change) => change.upcoming_change.impact_type === "feature",
      },
      {
        label: i18n("admin.upcoming_changes.filter.impact_type_other"),
        value: "other",
        filterFn: (change) => change.upcoming_change.impact_type === "other",
      },
      {
        label: i18n("admin.upcoming_changes.filter.status_pre_alpha"),
        value: "pre_alpha",
        filterFn: (change) => change.upcoming_change.status === "pre_alpha",
      },
      {
        label: i18n("admin.upcoming_changes.filter.status_alpha"),
        value: "alpha",
        filterFn: (change) => change.upcoming_change.status === "alpha",
      },
      {
        label: i18n("admin.upcoming_changes.filter.status_beta"),
        value: "beta",
        filterFn: (change) => change.upcoming_change.status === "beta",
      },
      {
        label: i18n("admin.upcoming_changes.filter.status_stable"),
        value: "stable",
        filterFn: (change) => change.upcoming_change.status === "stable",
      },
    ];
  }

  <template>
    <AdminFilterControls
      @array={{this.upcomingChanges}}
      @searchableProps={{array
        "humanized_name"
        "description"
        "plugin_identifier"
      }}
      @dropdownOptions={{this.dropdownOptions}}
      @inputPlaceholder={{i18n
        "admin.upcoming_changes.filter.search_placeholder"
      }}
      @noResultsMessage={{i18n
        "admin.upcoming_changes.filter.search_placeholder"
      }}
    >
      <:content as |upcomingChanges|>
        <table class="d-table upcoming-changes-table">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th
                class="d-table__header-cell upcoming-change__name-header"
              >{{i18n "admin.upcoming_changes.name"}}</th>
              <th
                class="d-table__header-cell upcoming-change__groups-header"
              >{{i18n "admin.upcoming_changes.opt_in_groups"}}</th>
              <th
                class="d-table__header-cell upcoming-change__enabled-header"
              ></th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each upcomingChanges as |change|}}
              <UpcomingChangeItem @change={{change}} />
            {{/each}}
          </tbody>
        </table>
      </:content>
    </AdminFilterControls>
  </template>
}
