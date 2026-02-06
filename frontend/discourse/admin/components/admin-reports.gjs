import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { service } from "@ember/service";
import AdminFilterControls from "discourse/admin/components/admin-filter-controls";
import AdminSectionLandingItem from "discourse/admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "discourse/admin/components/admin-section-landing-wrapper";
import AsyncContent from "discourse/components/async-content";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

const REPORT_GROUPS = {
  Engagement: {
    name: "Engagement",
    reports: [
      "mobile_visits",
      "visits",
      "dau_by_mau",
      "daily_engaged_users",
      "topic_view_stats",
      "new_contributors",
      "signups",
    ],
  },
  traffic: {
    name: "Traffic & Engagement",
    reports: [
      "page_view_total_reqs",
      "consolidated_page_views",
      "consolidated_page_views_browser_detection",
      "page_view_anon_browser_reqs",
      "site_traffic",
      "page_view_anon_reqs",
      "page_view_logged_in_reqs",
      "page_view_crawler_reqs",
      "page_view_legacy_total_reqs",
      "top_traffic_sources",
    ],
  },
  users: {
    name: "Members",
    reports: [
      "users_by_trust_level",
      "users_by_type",
      "trust_level_growth",
      "top_referrers",
      "top_users_by_likes_received",
      "top_ignored_users",
    ],
  },
  content: {
    name: "Content & Health",
    reports: [
      "posts",
      "topics",
      "topics_with_no_response",
      "time_to_first_response",
      "trending_search",
      "user_to_user_private_messages_with_replies",
      "top_referred_topics",
    ],
  },
  moderation: {
    name: "Moderation",
    reports: [
      "flags",
      "flags_status",
      "moderators_activity",
      "user_flagging_ratio",
    ],
  },
  security: {
    name: "Security",
    reports: [
      "emails",
      "web_crawlers",
      "consolidated_api_requests",
      "storage_stats",
      "web_hook_events_daily_aggregate",
      "suspicious_logins",
      "staff_logins",
      "associated_accounts_by_provider",
    ],
  },
  other: {
    name: "Other",
    reports: [],
  },
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

  @bind
  groupReports(reports) {
    if (!reports) {
      return [];
    }

    const groupedReports = [];
    const assignedReports = new Set();

    // First, separate core reports from plugin reports
    const coreReports = reports.filter((report) => !report.plugin);
    const pluginReports = reports.filter((report) => report.plugin);

    // Group core reports by category
    for (const [groupKey, groupConfig] of Object.entries(REPORT_GROUPS)) {
      const groupReports = coreReports.filter((report) =>
        groupConfig.reports.includes(report.type)
      );

      if (groupReports.length > 0) {
        groupedReports.push({
          key: groupKey,
          name: groupConfig.name,
          reports: groupReports,
        });
        groupReports.forEach((r) => assignedReports.add(r.type));
      }
    }

    // Add any core reports that weren't assigned to a group
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
          name: "Other",
          reports: unassignedCoreReports,
        });
      }
    }

    // Group plugin reports by plugin name
    const pluginGroups = new Map();
    for (const report of pluginReports) {
      const pluginName = report.plugin;
      if (!pluginGroups.has(pluginName)) {
        pluginGroups.set(pluginName, []);
      }
      pluginGroups.get(pluginName).push(report);
    }

    // Add plugin groups
    for (const [pluginName, pluginReportsList] of pluginGroups) {
      groupedReports.push({
        key: `plugin-${pluginName}`,
        name: this.formatPluginName(pluginName),
        reports: pluginReportsList,
        isPlugin: true,
      });
    }

    return groupedReports;
  }

  formatPluginName(pluginName) {
    // Convert "discourse-ai" to "Discourse AI"
    return pluginName
      .replace(/^discourse-/, "")
      .split("-")
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(" ");
  }

  <template>
    <AsyncContent @asyncData={{this.loadReports}}>
      <:content as |reports|>
        <AdminFilterControls
          @array={{this.filterReports reports}}
          @searchableProps={{array "title" "description"}}
          @inputPlaceholder={{i18n "admin.filter_reports"}}
          @noResultsMessage={{i18n "admin.filter_reports_no_results"}}
        >
          <:content as |filteredReports|>
            {{#each (this.groupReports filteredReports) as |group|}}
              <section class="admin-reports-group">
                <h3 class="admin-reports-group__title">{{group.name}}</h3>
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
    </AsyncContent>
  </template>
}
