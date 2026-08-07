import SiteSettingMatcher from "discourse/admin/lib/site-setting-matcher";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class SiteSettingFilter {
  constructor(siteSettings) {
    this.siteSettings = siteSettings;
  }

  filterSettings(filter, opts = {}) {
    opts.maxResults ??= 100;
    opts.onlyOverridden ??= false;
    opts.dependsOn ??= null;

    return this.performSearch(filter, opts);
  }

  @bind
  performSearch(filter, opts) {
    opts.includeAllCategory ??= true;

    let pluginFilter;
    let upcomingChangeDefaultOverrideFilter;

    if (filter) {
      filter = filter
        .toLowerCase()
        .split(" ")
        .filter((word) => {
          if (!word.length) {
            return false;
          }

          if (word.startsWith("plugin:")) {
            pluginFilter = word.slice("plugin:".length).trim();
            return false;
          }

          if (word.startsWith("upcoming_change_default_override:")) {
            upcomingChangeDefaultOverrideFilter = word
              .slice("upcoming_change_default_override:".length)
              .trim();
            return false;
          }

          return true;
        })
        .join(" ")
        .trim();
    }

    const matchesGroupedByCategory = [];
    const matches = [];

    let all;
    if (opts.includeAllCategory) {
      all = {
        nameKey: "all_results",
        name: i18n("admin.site_settings.categories.all_results"),
        siteSettings: [],
      };

      matchesGroupedByCategory.push(all);
    }

    this.siteSettings.forEach((settingsCategory) => {
      let fuzzyMatches = [];

      const matchedSiteSettings = settingsCategory.siteSettings.filter(
        (siteSetting) => {
          siteSetting.weight = 0;

          if (opts.onlyOverridden && !siteSetting.get("overridden")) {
            return false;
          }

          if (opts.dependsOn) {
            return (
              siteSetting.get("depends_on") &&
              siteSetting.get("depends_on").includes(opts.dependsOn)
            );
          }

          if (pluginFilter && siteSetting.plugin !== pluginFilter) {
            return false;
          }

          if (
            upcomingChangeDefaultOverrideFilter &&
            siteSetting.get("upcoming_change_default_override_metadata")
              ?.change_setting_name !== upcomingChangeDefaultOverrideFilter
          ) {
            return false;
          }

          if (!filter) {
            return true;
          }

          const matcher = new SiteSettingMatcher(filter, siteSetting);

          if (matcher.isNameMatch) {
            siteSetting.weight = 10;
            return true;
          }

          if (matcher.isKeywordMatch) {
            siteSetting.weight = 5;
            return true;
          }

          if (matcher.isDescriptionMatch) {
            return true;
          }

          if (matcher.isValueMatch) {
            return true;
          }

          if (matcher.isFuzzyNameMatch) {
            siteSetting.weight += matcher.matchStrength;
            fuzzyMatches.push(siteSetting);

            return true;
          }

          return false;
        }
      );
      const siteSettings = opts.dependsOn
        ? matchedSiteSettings
        : this.displaySettingsFor(matchedSiteSettings);

      if (siteSettings.length > 0) {
        matches.push(...siteSettings);
        matchesGroupedByCategory.push({
          nameKey: settingsCategory.nameKey,
          name: i18n(
            "admin.site_settings.categories." + settingsCategory.nameKey
          ),
          siteSettings: this.sortSettings(siteSettings),
          count: siteSettings.length,
        });
      }
    });

    if (opts.includeAllCategory) {
      all.siteSettings.push(...matches.slice(0, opts.maxResults));
      all.siteSettings = this.sortSettings(all.siteSettings);

      all.hasMore = matches.length > opts.maxResults;
      all.count = all.hasMore ? `${opts.maxResults}+` : matches.length;
      all.maxResults = opts.maxResults;
    }

    return matchesGroupedByCategory;
  }

  @bind
  sortSettings(settings) {
    // Sort the site settings so that fuzzy results are at the bottom
    // and ordered by their match strength.
    return settings.sort((a, b) => {
      return (b.weight || 0) - (a.weight || 0);
    });
  }

  displaySettingsFor(settings) {
    const displaySettings = [];

    settings.forEach((setting) => {
      const displaySetting = this.displaySettingFor(setting);

      if (displaySetting !== setting) {
        displaySetting.weight = Math.max(
          displaySetting.weight || 0,
          setting.weight || 0
        );
      }

      if (!displaySettings.includes(displaySetting)) {
        displaySettings.push(displaySetting);
      }
    });

    return displaySettings;
  }

  displaySettingFor(setting) {
    if (
      setting.depends_behavior !== "hidden" ||
      setting.dependent_setting_display !== "inline" ||
      !setting.depends_on?.length
    ) {
      return setting;
    }

    return this.findSetting(setting.depends_on[0]) || setting;
  }

  findSetting(name) {
    for (const settingsCategory of this.siteSettings) {
      const setting = settingsCategory.siteSettings.find(
        (siteSetting) => siteSetting.setting === name
      );

      if (setting) {
        return setting;
      }
    }
  }
}
