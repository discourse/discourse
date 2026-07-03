import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { service } from "@ember/service";
import AdminFilterControls from "discourse/admin/components/admin-filter-controls";
import AdminSectionLandingItem from "discourse/admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "discourse/admin/components/admin-section-landing-wrapper";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import { i18n } from "discourse-i18n";

const REPORT_GROUPS = {
  engagement: [
    "daily_engaged_users",
    "dau_by_mau",
    "mobile_visits",
    "new_contributors",
    "signups",
    "topic_view_stats",
    "visits",
  ],
  traffic: [
    "consolidated_page_views",
    "consolidated_page_views_browser_detection",
    "page_view_anon_browser_reqs",
    "page_view_anon_reqs",
    "page_view_crawler_reqs",
    "page_view_legacy_total_reqs",
    "page_view_logged_in_reqs",
    "page_view_logged_in_browser_reqs",
    "page_view_total_reqs",
    "site_traffic",
    "top_traffic_sources",
  ],
  members: [
    "top_ignored_users",
    "top_referrers",
    "top_users_by_likes_received",
    "trust_level_growth",
    "users_by_trust_level",
    "users_by_type",
  ],
  content: [
    "posts",
    "time_to_first_response",
    "top_referred_topics",
    "top_uploads",
    "topics",
    "topics_with_no_response",
    "trending_search",
    "user_to_user_private_messages_with_replies",
  ],
  moderation_and_security: [
    "admin_logins",
    "associated_accounts_by_provider",
    "consolidated_api_requests",
    "emails",
    "flags",
    "flags_status",
    "moderators_activity",
    "suspicious_logins",
    "user_flagging_ratio",
    "web_crawlers",
    "web_hook_events_daily_aggregate",
  ],
  other: [],
};

export default class AdminReports extends Component {
  @service siteSettings;

  @bind
  async loadReports() {
    const response = await ajax("/admin/reports");
    return response.reports;
  }

  @bind
  filterReports(reports) {
    if (!reports) {
      return [];
    }

    const hiddenReports = (this.siteSettings.dashboard_hidden_reports || "")
      .split("|")
      .filter(Boolean);
    return reports.filter((report) => !hiddenReports.includes(report.type));
  }

  get requestedGroupKey() {
    return this.args.group || "all";
  }

  @bind
  groupReports(reports) {
    if (!reports) {
      return [];
    }

    const groupedReports = [];
    const assignedReports = new Set();

    const coreReports = reports.filter((report) => !report.plugin);
    const pluginReports = reports.filter((report) => report.plugin);

    for (const [groupKey, groupReportTypes] of Object.entries(REPORT_GROUPS)) {
      const groupReports = coreReports.filter((report) =>
        groupReportTypes.includes(report.type)
      );

      if (groupReports.length > 0) {
        groupedReports.push({
          key: groupKey,
          name: i18n(`admin.reports.group_${groupKey}`),
          reports: groupReports,
        });
        groupReports.forEach((r) => assignedReports.add(r.type));
      }
    }

    const unassignedCoreReports = coreReports.filter(
      (report) => !assignedReports.has(report.type)
    );
    if (unassignedCoreReports.length > 0) {
      const otherGroup = groupedReports.find((g) => g.key === "other");
      if (otherGroup) {
        otherGroup.reports.push(...unassignedCoreReports);
      } else {
        groupedReports.push({
          key: "other",
          name: i18n("admin.reports.group_other"),
          reports: unassignedCoreReports,
        });
      }
    }

    const pluginGroups = new Map();
    for (const report of pluginReports) {
      const pluginName = report.plugin;
      if (!pluginGroups.has(pluginName)) {
        pluginGroups.set(pluginName, []);
      }
      pluginGroups.get(pluginName).push(report);
    }

    const sortedPluginGroups = [...pluginGroups.entries()]
      .map(([pluginName, pluginReportsList]) => ({
        key: `plugin-${pluginName}`,
        name: pluginReportsList[0].plugin_display_name || pluginName,
        reports: pluginReportsList,
      }))
      .sort((a, b) => a.name.localeCompare(b.name));

    groupedReports.push(...sortedPluginGroups);

    return groupedReports;
  }

  @bind
  groupDropdownOptions(reports) {
    const groups = this.groupReports(this.filterReports(reports));

    return [
      {
        value: "all",
        label: i18n("admin.reports.all_groups"),
        filterFn: () => true,
      },
      ...groups.map((group) => ({
        value: group.key,
        label: group.name,
        filterFn: (report) => group.reports.includes(report),
      })),
    ];
  }

  @bind
  selectedGroupKey(reports) {
    const options = this.groupDropdownOptions(reports);

    return options.some((option) => option.value === this.requestedGroupKey)
      ? this.requestedGroupKey
      : "all";
  }

  @bind
  filterReportsByGroup(reports, availableReports) {
    const selectedGroupKey = this.selectedGroupKey(availableReports);

    if (selectedGroupKey === "all") {
      return reports;
    }

    const group = this.groupReports(this.filterReports(availableReports)).find(
      (reportGroup) => reportGroup.key === selectedGroupKey
    );

    return group?.reports
      ? reports.filter((report) => group.reports.includes(report))
      : reports;
  }

  @bind
  updateGroupFilter(groupKey) {
    this.args.onGroupChange?.(groupKey);
  }

  <template>
    <DAsyncContent @asyncData={{this.loadReports}}>
      <:content as |reports|>
        <AdminFilterControls
          @array={{this.filterReports reports}}
          @searchableProps={{array "title" "description"}}
          @dropdownOptions={{this.groupDropdownOptions reports}}
          @defaultDropdownValue={{this.selectedGroupKey reports}}
          @inputPlaceholder={{i18n "admin.filter_reports"}}
          @noResultsMessage={{i18n "admin.filter_reports_no_results"}}
          @onClientDropdownFilterChange={{this.updateGroupFilter}}
        >
          <:content as |filteredReports|>
            {{#each
              (this.groupReports
                (this.filterReportsByGroup filteredReports reports)
              )
              as |group|
            }}
              <section class="admin-reports-group">
                <h2 class="admin-reports-group__title">{{group.name}}</h2>
                <AdminSectionLandingWrapper class="admin-reports-list">
                  {{#each group.reports as |report|}}
                    <AdminSectionLandingItem
                      @titleLabelTranslated={{report.title}}
                      @descriptionLabelTranslated={{report.description}}
                      @titleRoute="adminReports.show"
                      @titleRouteModel={{report.type}}
                    />
                  {{/each}}
                </AdminSectionLandingWrapper>
              </section>
            {{/each}}
          </:content>
        </AdminFilterControls>
      </:content>
    </DAsyncContent>
  </template>
}
