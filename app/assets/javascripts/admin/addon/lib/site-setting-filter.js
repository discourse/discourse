import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import SiteSettingMatcher from "admin/lib/site-setting-matcher";

export default class SiteSettingFilter {
  constructor(siteSettings) {
    this.siteSettings = siteSettings;
  }

  filterSettings(filter, opts = {}) {
    opts.maxResults ??= 100;
    opts.onlyOverridden ??= false;

    return this.performSearch(filter, opts);
  }

  @bind
  performSearch(filter, opts) {
    opts.includeAllCategory ??= true;

    let pluginFilter;

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

      const siteSettings = settingsCategory.siteSettings.filter(
        (siteSetting) => {
          siteSetting.weight = 0;

          if (opts.onlyOverridden && !siteSetting.get("overridden")) {
            return false;
          }

          if (pluginFilter && siteSetting.plugin !== pluginFilter) {
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

      if (siteSettings.length > 0) {
        matches.pushObjects(siteSettings);
        matchesGroupedByCategory.pushObject({
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
      all.siteSettings.pushObjects(matches.slice(0, opts.maxResults));
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
}
