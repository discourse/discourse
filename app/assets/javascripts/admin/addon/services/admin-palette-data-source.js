import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import escapeRegExp from "discourse/lib/escape-regexp";
import getURL from "discourse/lib/get-url";
import PreloadStore from "discourse/lib/preload-store";
import { ADMIN_NAV_MAP } from "discourse/lib/sidebar/admin-nav-map";
import I18n, { i18n } from "discourse-i18n";

const RESULT_TYPES = ["page", "setting", "theme", "component"];

export default class AdminPaletteDataSource extends Service {
  @service router;
  @service siteSettings;

  pageMapItems = [];
  settingMapItems = [];
  themeMapItems = [];
  componentMapItems = [];
  settingPageMap = {
    categories: {},
    areas: {},
  };
  _mapCached = false;

  buildMap() {
    if (this._mapCached) {
      return;
    }
    ADMIN_NAV_MAP.forEach((mapItem) => {
      mapItem.links.forEach((link) => {
        let url;
        if (link.routeModels) {
          url = this.router.urlFor(link.route, ...link.routeModels);
        } else {
          url = this.router.urlFor(link.route);
        }

        const mapItemLabel =
          mapItem.text || (mapItem.label ? i18n(mapItem.label) : "");
        const label =
          mapItemLabel +
          (mapItemLabel ? " > " : "") +
          (link.text || (link.label ? i18n(link.label) : ""));

        if (link.settings_area) {
          this.settingPageMap.areas[link.settings_area] = link.multi_tabbed
            ? `${url}/settings`
            : url;
        }

        if (link.settings_category) {
          this.settingPageMap.categories[link.settings_category] =
            link.multi_tabbed ? `${url}/settings` : url;
        }

        this.pageMapItems.push({
          label,
          url,
          keywords:
            (link.keywords ? i18n(link.keywords).toLowerCase() : "") +
            " " +
            url +
            " " +
            label.toLowerCase(),
          type: "page",
          icon: link.icon,
          description: link.description ? i18n(link.description) : "",
        });
      });
    });

    // TODO (martin) Probably hash these with the plugin name as key
    const visiblePlugins = (PreloadStore.get("visiblePlugins") || []).filter(
      (plugin) => plugin.admin_route && plugin.enabled
    );
    ajax("/admin/palette/settings.json").then((result) => {
      result.forEach((setting) => {
        // TODO: (martin) Might want to use the sidebar link name for this instead of the
        // plugin category?

        let rootLabel;
        if (setting.plugin) {
          rootLabel =
            I18n.lookup(
              `admin.site_settings.categories.${setting.plugin.replaceAll(
                "-",
                "_"
              )}`
            ) || i18n("admin.plugins.title");
        } else if (setting.primary_area) {
          rootLabel =
            I18n.lookup(`admin.config.${setting.primary_area}.title`) ||
            i18n(`admin.site_settings.categories.${setting.category}`);
        } else {
          rootLabel = i18n(
            `admin.site_settings.categories.${setting.category}`
          );
        }
        const label = rootLabel + " > " + setting.setting;

        let url;
        if (setting.plugin) {
          const plugin = visiblePlugins.find(
            (visiblePlugin) => visiblePlugin.name === setting.plugin
          );
          if (plugin && plugin.admin_route) {
            url = plugin.admin_route.use_new_show_route
              ? this.router.urlFor(
                  `adminPlugins.show.settings`,
                  plugin.admin_route.location,
                  { queryParams: { filter: setting.setting } }
                )
              : this.router.urlFor(
                  `adminPlugins.${plugin.admin_route.location}`
                );
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
          keywords: (
            setting.setting +
            " " +
            setting.setting.split("_").join(" ") +
            " " +
            setting.description +
            " " +
            setting.keywords.join(" ") +
            " " +
            rootLabel
          ).toLowerCase(),
          type: "setting",
          icon: "gear",
        });
      });
    });
    ajax("/admin/palette/themes-and-components.json").then((result) => {
      result.forEach((themeOrComponent) => {
        if (themeOrComponent.component) {
          this.componentMapItems.push({
            label: themeOrComponent.name,
            description: themeOrComponent.description,
            url: getURL(`/admin/customize/components/${themeOrComponent.id}`),
            keywords: (
              "component" +
              " " +
              themeOrComponent.description +
              " " +
              themeOrComponent.name
            ).toLowerCase(),
            type: "component",
            icon: "puzzle-piece",
          });
        } else {
          this.themeMapItems.push({
            label: themeOrComponent.name,
            description: themeOrComponent.description,
            url: getURL(`/admin/customize/themes/${themeOrComponent.id}`),
            keywords: (
              "theme" +
              " " +
              themeOrComponent.description +
              " " +
              themeOrComponent.name
            ).toLowerCase(),
            type: "theme",
            icon: "paintbrush",
          });
        }
      });
    });
    this._mapCached = true;
  }

  search(filter, opts = {}) {
    if (filter.length < 2) {
      return [];
    }
    opts.types = opts.types || RESULT_TYPES;
    const filteredResults = [];
    const escapedFilterRegExp = escapeRegExp(filter.toLowerCase());

    opts.types.forEach((type) => {
      this[`${type}MapItems`].forEach((mapItem) => {
        if (mapItem.keywords.match(escapedFilterRegExp)) {
          filteredResults.push(mapItem);
        }
      });
    });

    return filteredResults;
  }
}
