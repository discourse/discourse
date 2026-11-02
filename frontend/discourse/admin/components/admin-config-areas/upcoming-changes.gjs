import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import UpcomingChangeItem from "discourse/admin/components/admin-config-areas/upcoming-change-item";
import { AUTO_GROUPS } from "discourse/lib/constants";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import { i18n } from "discourse-i18n";

// most mature first, as those are closest to being enabled automatically
const STATUS_ORDER = ["stable", "beta", "alpha", "experimental"];

const DEFAULT_SORT = "recently_updated";

function compareNames(a, b) {
  return a.humanized_name.localeCompare(b.humanized_name);
}

function compareStatuses(a, b) {
  return (
    STATUS_ORDER.indexOf(a.upcoming_change.status) -
    STATUS_ORDER.indexOf(b.upcoming_change.status)
  );
}

// changes not yet seen by the tracking job have no timestamp, but are the newest
function compareRecentlyUpdated(a, b) {
  const aTime = a.upcoming_change.status_changed_at
    ? Date.parse(a.upcoming_change.status_changed_at)
    : Infinity;
  const bTime = b.upcoming_change.status_changed_at
    ? Date.parse(b.upcoming_change.status_changed_at)
    : Infinity;

  return aTime === bTime ? 0 : bTime > aTime ? 1 : -1;
}

function compareBy(...comparators) {
  return (a, b) => {
    for (const compare of comparators) {
      const result = compare(a, b);
      if (result !== 0) {
        return result;
      }
    }
    return 0;
  };
}

const SORTS = {
  recently_updated: compareBy(
    compareRecentlyUpdated,
    compareStatuses,
    compareNames
  ),
  status: compareBy(compareStatuses, compareRecentlyUpdated, compareNames),
  name: compareNames,
};

export default class AdminConfigAreasUpcomingChanges extends Component {
  @service site;

  @cached
  get upcomingChanges() {
    return this.args.upcomingChanges.map((change) => {
      change.upcoming_change = trackedObject(change.upcoming_change);
      return trackedObject(change);
    });
  }

  get sortOptions() {
    return Object.entries(SORTS).map(([value, compareFn]) => ({
      value,
      label: i18n(`admin.upcoming_changes.sort.${value}`),
      compareFn,
    }));
  }

  get staffGroupName() {
    return this.site.groupsById[AUTO_GROUPS.staff.id].name;
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
        {
          label: i18n(
            "admin.upcoming_changes.filter.impact_type_site_setting_default"
          ),
          value: "site_setting_default",
          filterFn: (change) =>
            change.upcoming_change.impact_type === "site_setting_default",
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
          filterFn: (change) =>
            change.upcoming_change.enabled_for === "everyone",
        },
        {
          label: i18n("admin.upcoming_changes.filter.enabled_for_staff", {
            staffGroupName: this.staffGroupName,
          }),
          value: "enabled_for_staff",
          filterFn: (change) => change.upcoming_change.enabled_for === "staff",
        },
        {
          label: i18n(
            "admin.upcoming_changes.filter.enabled_for_specific_groups"
          ),
          value: "enabled_for_specific_groups",
          filterFn: (change) => change.upcoming_change.enabled_for === "groups",
        },
        {
          label: i18n("admin.upcoming_changes.filter.disabled"),
          value: "disabled",
          filterFn: (change) => !change.value,
        },
      ],
    };
  }

  @action
  enabledForChanged(changeSettingName, newEnabledFor) {
    this.upcomingChanges.find(
      (change) => change.setting === changeSettingName
    ).upcoming_change.enabled_for = newEnabledFor;
  }

  <template>
    <DFilterControls
      @array={{this.upcomingChanges}}
      @defaultSort={{DEFAULT_SORT}}
      @dropdownFilterQueryParams={{hash
        status="status"
        type="type"
        impactRole="impactRole"
        enabled="enabled"
      }}
      @dropdownOptions={{this.dropdownOptions}}
      @initialTextFilter={{@changeNamesFilter}}
      @inputPlaceholder={{i18n
        "admin.upcoming_changes.filter.search_placeholder"
      }}
      @noResultsMessage={{i18n
        "admin.upcoming_changes.filter.search_placeholder"
      }}
      @onResetFilters={{@onClearChangeNamesFilter}}
      @searchableProps={{array
        "humanized_name"
        "description"
        "plugin_identifier"
        "setting"
      }}
      @sortOptions={{this.sortOptions}}
      @sortQueryParam="sort"
      @textFilterQueryParam="changeNamesFilter"
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
              <UpcomingChangeItem
                @change={{change}}
                @enabledForChanged={{@enabledForChanged}}
              />
            {{/each}}
          </tbody>
        </table>
      </:content>
    </DFilterControls>

    {{#unless this.upcomingChanges}}
      <AdminConfigAreaEmptyList
        @emptyLabel="admin.upcoming_changes.no_changes"
      />
    {{/unless}}
  </template>
}
