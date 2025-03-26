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

export default class AdminSearchDataSource extends Service {
  @service router;
  @service siteSettings;

  plugins = {};
  pageMapItems = [];
  settingMapItems = [];
  themeMapItems = [];
  componentMapItems = [];
  reportMapItems = [];
  settingPageMap = {
    categories: {},
    areas: {},
  };
  @tracked _mapCached = false;

  get isLoaded() {
    return this._mapCached;
  }

  async buildMap() {
    if (this._mapCached) {
      return;
    }

    ADMIN_NAV_MAP.forEach((mapItem) => {
      mapItem.links.forEach((link) => {
        let parentLabel = this.#addPageLink(mapItem, link);

        link.links?.forEach((subLink) => {
          this.#addPageLink(mapItem, subLink, parentLabel);
        });
      });
    });

    // TODO (martin) Handle plugin enabling/disabling via MessageBus for this
    // and the setting list?
    (PreloadStore.get("visiblePlugins") || {}).forEach((plugin) => {
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
      this[`${type}MapItems`].forEach((mapItem) => {
        // TODO (martin) There is likely a much better way of doing this matching
        // that will support fuzzy searches, for now let's go with the most basic thing.
        if (
          mapItem.keywords.match(escapedFilterRegExp) &&
          typeItemCount <= perTypeLimit
        ) {
          filteredResults.push(mapItem);
          typeItemCount++;
        }
      });
    });

    return filteredResults;
  }

  #addPageLink(mapItem, link, parentLabel = "") {
    let url;
    if (link.route) {
      if (link.routeModels) {
        url = this.router.urlFor(link.route, ...link.routeModels);
      } else {
        url = this.router.urlFor(link.route);
      }
    } else if (link.href) {
      url = getURL(link.href);
    }

    const mapItemLabel = this.#labelOrText(mapItem);
    const linkLabel = this.#labelOrText(link);

    let label;
    if (parentLabel) {
      label = mapItemLabel;
      if (mapItemLabel) {
        label += ` ${SEPARATOR} `;
      }
      label += `${parentLabel} ${SEPARATOR} ${linkLabel}`;
    } else {
      label = mapItemLabel + (mapItemLabel ? ` ${SEPARATOR} ` : "") + linkLabel;
    }

    if (link.settings_area) {
      this.settingPageMap.areas[link.settings_area] = link.multi_tabbed
        ? `${url}/settings`
        : url;
    }

    if (link.settings_category) {
      this.settingPageMap.categories[link.settings_category] = link.multi_tabbed
        ? `${url}/settings`
        : url;
    }

    const linkKeywords = link.keywords
      ? i18n(link.keywords).toLowerCase().replaceAll("|", " ")
      : "";
    const linkDescription = link.description
      ? link.description.includes(" ")
        ? link.description
        : i18n(link.description)
      : "";

    this.pageMapItems.push({
      label,
      url,
      keywords: this.#buildKeywords(
        linkKeywords,
        url,
        label.replace(SEPARATOR, "").toLowerCase().replace(/  +/g, " "),
        linkDescription
      ),
      type: "page",
      icon: link.icon,
      description: linkDescription,
    });

    return linkLabel;
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

      this.settingMapItems.push({
        label,
        description: setting.description,
        url,
        keywords: this.#buildKeywords(
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
        this.componentMapItems.push({
          label: themeOrComponent.name,
          description: themeOrComponent.description,
          url: getURL(`/admin/customize/components/${themeOrComponent.id}`),
          keywords: this.#buildKeywords(
            "component",
            themeOrComponent.description,
            themeOrComponent.name
          ),
          type: "component",
          icon: "puzzle-piece",
        });
      } else {
        this.themeMapItems.push({
          label: themeOrComponent.name,
          description: themeOrComponent.description,
          url: getURL(`/admin/customize/themes/${themeOrComponent.id}`),
          keywords: this.#buildKeywords(
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
      this.reportMapItems.push({
        label: report.title,
        description: report.description,
        url: getURL(`/admin/reports/${report.type}`),
        icon: "chart-bar",
        keywords: this.#buildKeywords(
          report.title,
          report.description,
          report.type
        ),
        type: "report",
      });
    });
  }

  #labelOrText(obj, fallback = "") {
    return obj.text || (obj.label ? i18n(obj.label) : fallback);
  }

  #buildKeywords(...keywords) {
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
}
