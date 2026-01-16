import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import UpcomingChangeItem from "discourse/admin/components/admin-config-areas/upcoming-change-item";
import AdminFilterControls from "discourse/admin/components/admin-filter-controls";
import { i18n } from "discourse-i18n";

export default class AdminConfigAreasUpcomingChanges extends Component {
  get upcomingChanges() {
    return this.args.upcomingChanges.map((change) => {
      change.upcoming_change = new TrackedObject(change.upcoming_change);
      return new TrackedObject(change);
    });
  }

  get dropdownOptions() {
    return {
      status: [
        {
          label: i18n("admin.upcoming_changes.filter.status_all"),
          value: "all",
          filterFn: () => true,
        },
        {
          label: i18n("admin.upcoming_changes.filter.status_experimental"),
          value: "experimental",
          filterFn: (change) =>
            change.upcoming_change.status === "experimental",
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
        {
          label: i18n("admin.upcoming_changes.filter.status_permanent"),
          value: "permanent",
          filterFn: (change) => change.upcoming_change.status === "permanent",
        },
      ],
      type: [
        {
          label: i18n("admin.upcoming_changes.filter.impact_type_all"),
          value: "all",
          filterFn: () => true,
        },
        {
          label: i18n("admin.upcoming_changes.filter.impact_type_feature"),
          value: "feature",
          filterFn: (change) =>
            change.upcoming_change.impact_type === "feature",
        },
        {
          label: i18n("admin.upcoming_changes.filter.impact_type_other"),
          value: "other",
          filterFn: (change) => change.upcoming_change.impact_type === "other",
        },
      ],
      impactRole: [
        {
          label: i18n("admin.upcoming_changes.filter.impact_role_all"),
          value: "all",
          filterFn: () => true,
        },
        {
          label: i18n("admin.upcoming_changes.filter.impact_role_admins"),
          value: "admins",
          filterFn: (change) => change.upcoming_change.impact_role === "admins",
        },
        {
          label: i18n("admin.upcoming_changes.filter.impact_role_moderators"),
          value: "moderators",
          filterFn: (change) =>
            change.upcoming_change.impact_role === "moderators",
        },
        {
          label: i18n("admin.upcoming_changes.filter.impact_role_staff"),
          value: "staff",
          filterFn: (change) => change.upcoming_change.impact_role === "staff",
        },
        {
          label: i18n("admin.upcoming_changes.filter.impact_role_all_members"),
          value: "all_members",
          filterFn: (change) =>
            change.upcoming_change.impact_role === "all_members",
        },
        {
          label: i18n("admin.upcoming_changes.filter.impact_role_developers"),
          value: "developers",
          filterFn: (change) =>
            change.upcoming_change.impact_role === "developers",
        },
      ],
      enabled: [
        {
          label: i18n("admin.upcoming_changes.filter.enabled_all"),
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
      ],
    };
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
                class="d-table__header-cell upcoming-change__enabled-header"
              >{{i18n "admin.upcoming_changes.enabled_for"}}</th>
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

    {{#unless this.upcomingChanges}}
      <AdminConfigAreaEmptyList
        @emptyLabel="admin.upcoming_changes.no_changes"
      />
    {{/unless}}
  </template>
}
