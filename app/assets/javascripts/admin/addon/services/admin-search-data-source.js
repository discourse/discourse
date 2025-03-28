import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { adminRouteValid } from "discourse/lib/admin-utilities";
import { ajax } from "discourse/lib/ajax";
import { ADMIN_SEARCH_RESULT_TYPES } from "discourse/lib/constants";
import escapeRegExp from "discourse/lib/escape-regexp";
import getURL from "discourse/lib/get-url";
import PreloadStore from "discourse/lib/preload-store";
import { ADMIN_NAV_MAP } from "discourse/lib/sidebar/admin-nav-map";
import { humanizedSettingName } from "discourse/lib/site-settings-utils";
import I18n, { i18n } from "discourse-i18n";

const SEPARATOR = ">";
const MIN_FILTER_LENGTH = 2;
const MAX_TYPE_RESULT_COUNT_LOW = 15;
const MAX_TYPE_RESULT_COUNT_HIGH = 50;

function labelOrText(obj, fallback = "") {
  return obj.text || (obj.label ? i18n(obj.label) : fallback);
}

function buildKeywords(...keywords) {
  return keywords
    .map((kw) => {
      if (Array.isArray(kw)) {
        return kw.join(" ");
      }
      return kw;
    })
    .join(" ")
    .toLowerCase();
}

export class PageLinkFormatter {
  /**
   * @param {DiscourseRouter} router - The ember router service
   * @param {Object} navMapSection - The section of the admin nav map that the link belongs to,
   *                                 used for the parent label.
   * @param {Object} link - The link object from the admin nav map, with name/route/label etc.
   * @param {String} parentLabel - The parent label of the link, if any.
   */
  constructor(router, navMapSection, link, parentLabel = null) {
    this.router = router;
    this.navMapSection = navMapSection;
    this.link = link;
    this.parentLabel = parentLabel;
  }

  format() {
    let url;
    if (this.link.route) {
      if (this.link.routeModels) {
        url = this.router.urlFor(this.link.route, ...this.link.routeModels);
      } else {
        url = this.router.urlFor(this.link.route);
      }
    } else if (this.link.href) {
      url = getURL(this.link.href);
    }

    const sectionLabel = labelOrText(this.navMapSection);
    const linkLabel = labelOrText(this.link);

    let label;
    if (this.parentLabel) {
      label = sectionLabel;
      if (sectionLabel) {
        label += ` ${SEPARATOR} `;
      }
      label += `${this.parentLabel} ${SEPARATOR} ${linkLabel}`;
    } else {
      label = sectionLabel + (sectionLabel ? ` ${SEPARATOR} ` : "") + linkLabel;
    }

    let keywords = this.link.keywords
      ? i18n(this.link.keywords).toLowerCase().replaceAll("|", " ")
      : "";
    const description = this.link.description
      ? this.link.description.includes(" ")
        ? this.link.description
        : i18n(this.link.description)
      : "";

    keywords = buildKeywords(
      keywords,
      url,
      label.replace(SEPARATOR, "").toLowerCase().replace(/  +/g, " "),
      description
    );

    return { url, label, keywords, description };
  }
}

export default class AdminSearchDataSource extends Service {
  @service router;
  @service siteSettings;

  plugins = {};
  pageDataSourceItems = [];
  settingDataSourceItems = [];
  themeDataSourceItems = [];
  componentDataSourceItems = [];
  reportDataSourceItems = [];
  settingPageMap = {
    categories: {},
    areas: {},
  };
  @tracked _mapCached = false;

  get isLoaded() {
    return this._mapCached;
  }

  async buildMap() {
    if (this.isLoaded) {
      return;
    }

    ADMIN_NAV_MAP.forEach((navMapSection) => {
      navMapSection.links.forEach((link) => {
        let parentLabel = this.#addPageLink(navMapSection, link);

        link.links?.forEach((subLink) => {
          this.#addPageLink(navMapSection, subLink, parentLabel);
        });
      });
    });

    // TODO (martin) Handle plugin enabling/disabling via MessageBus for this
    // and the setting list?
    (PreloadStore.get("visiblePlugins") || []).forEach((plugin) => {
      if (
        plugin.admin_route &&
        plugin.enabled &&
        adminRouteValid(this.router, plugin.admin_route)
      ) {
        this.plugins[plugin.name] = plugin;
      }
    });

    const allItems = await ajax("/admin/search/all.json");
    this.#processSettings(allItems.settings);
    this.#processThemesAndComponents(allItems.themes_and_components);
    this.#processReports(allItems.reports);
    await Promise.resolve();

    this._mapCached = true;
  }

  search(filter, opts = {}) {
    if (filter.length < MIN_FILTER_LENGTH) {
      return [];
    }

    opts.types = opts.types || ADMIN_SEARCH_RESULT_TYPES;

    const filteredResults = [];
    const escapedFilterRegExp = escapeRegExp(filter.toLowerCase());

    // Pointless to render heaps of settings if the filter is quite low.
    const perTypeLimit =
      filter.length < MIN_FILTER_LENGTH + 1
        ? MAX_TYPE_RESULT_COUNT_LOW
        : MAX_TYPE_RESULT_COUNT_HIGH;

    opts.types.forEach((type) => {
      let typeItemCount = 0;
      this[`${type}DataSourceItems`].forEach((dataSourceItem) => {
        // TODO (martin) There is likely a much better way of doing this matching
        // that will support fuzzy searches, for now let's go with the most basic thing.
        if (
          dataSourceItem.keywords.match(escapedFilterRegExp) &&
          typeItemCount <= perTypeLimit
        ) {
          filteredResults.push(dataSourceItem);
          typeItemCount++;
        }
      });
    });

    return filteredResults;
  }

  #addPageLink(navMapSection, link, parentLabel = "") {
    const formattedPageLink = new PageLinkFormatter(
      this.router,
      navMapSection,
      link,
      parentLabel
    ).format();

    // Cache the setting area + category URLs for later use
    // when building the setting list via #processSettings.
    if (link.settings_area && !this.settingPageMap.areas[this.settings_area]) {
      this.settingPageMap.areas[link.settings_area] = link.multi_tabbed
        ? `${formattedPageLink.url}/settings`
        : formattedPageLink.url;
    }

    if (
      link.settings_category &&
      !this.settingPageMap.categories[link.settings_category]
    ) {
      this.settingPageMap.categories[link.settings_category] = link.multi_tabbed
        ? `${formattedPageLink.url}/settings`
        : formattedPageLink.url;
    }

    this.pageDataSourceItems.push({
      label: formattedPageLink.label,
      url: formattedPageLink.url,
      keywords: formattedPageLink.keywords,
      type: "page",
      icon: link.icon,
      description: formattedPageLink.description,
    });

    return formattedPageLink.label;
  }

  #processSettings(settings) {
    const settingPluginNames = {};

    settings.forEach((setting) => {
      let plugin;

      let rootLabel;
      if (setting.plugin) {
        if (!settingPluginNames[setting.plugin]) {
          settingPluginNames[setting.plugin] = setting.plugin.replaceAll(
            "_",
            "-"
          );
        }

        plugin = this.plugins[settingPluginNames[setting.plugin]];

        if (plugin) {
          rootLabel = plugin.admin_route?.label
            ? i18n(plugin.admin_route?.label)
            : i18n("admin.plugins.title");
        } else {
          rootLabel = i18n("admin.plugins.title");
        }
      } else if (setting.primary_area) {
        rootLabel =
          I18n.lookup(`admin.config.${setting.primary_area}.title`) ||
          i18n(`admin.site_settings.categories.${setting.category}`);
      } else {
        rootLabel = i18n(`admin.site_settings.categories.${setting.category}`);
      }

      const label = `${rootLabel} ${SEPARATOR} ${humanizedSettingName(
        setting.setting
      )}`;

      // TODO (martin) These URLs will need to change eventually to anchors
      // to focus on a specific element on the page, for now though the filter is fine.
      let url;
      if (setting.plugin) {
        if (plugin) {
          url = plugin.admin_route.use_new_show_route
            ? this.router.urlFor(
                `adminPlugins.show.settings`,
                plugin.admin_route.location,
                { queryParams: { filter: setting.setting } }
              )
            : this.router.urlFor(`adminPlugins.${plugin.admin_route.location}`);
        } else {
          url = getURL(
            `/admin/site_settings/category/all_results?filter=${setting.setting}`
          );
        }
      } else if (this.settingPageMap.areas[setting.primary_area]) {
        url =
          this.settingPageMap.areas[setting.primary_area] +
          `?filter=${setting.setting}`;
      } else if (this.settingPageMap.categories[setting.category]) {
        url =
          this.settingPageMap.categories[setting.category] +
          `?filter=${setting.setting}`;
      } else {
        url = getURL(
          `/admin/site_settings/category/all_results?filter=${setting.setting}`
        );
      }

      this.settingDataSourceItems.push({
        label,
        description: setting.description,
        url,
        keywords: buildKeywords(
          setting.setting,
          humanizedSettingName(setting.setting),
          setting.description,
          setting.keywords,
          rootLabel
        ),
        type: "setting",
        icon: "gear",
      });
    });
  }

  #processThemesAndComponents(themesAndComponents) {
    themesAndComponents.forEach((themeOrComponent) => {
      if (themeOrComponent.component) {
        this.componentDataSourceItems.push({
          label: themeOrComponent.name,
          description: themeOrComponent.description,
          url: getURL(`/admin/customize/components/${themeOrComponent.id}`),
          keywords: buildKeywords(
            "component",
            themeOrComponent.description,
            themeOrComponent.name
          ),
          type: "component",
          icon: "puzzle-piece",
        });
      } else {
        this.themeDataSourceItems.push({
          label: themeOrComponent.name,
          description: themeOrComponent.description,
          url: getURL(`/admin/customize/themes/${themeOrComponent.id}`),
          keywords: buildKeywords(
            "theme",
            themeOrComponent.description,
            themeOrComponent.name
          ),
          type: "theme",
          icon: "paintbrush",
        });
      }
    });
  }

  #processReports(reports) {
    reports.forEach((report) => {
      this.reportDataSourceItems.push({
        label: report.title,
        description: report.description,
        url: getURL(`/admin/reports/${report.type}`),
        icon: "chart-bar",
        keywords: buildKeywords(report.title, report.description, report.type),
        type: "report",
      });
    });
  }
}
