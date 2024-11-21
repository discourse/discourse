import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

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

    const strippedQuery = filter.replace(/[^a-z0-9]/gi, "");
    let fuzzyRegex;
    let fuzzyRegexGaps;

    if (strippedQuery.length > 2) {
      fuzzyRegex = new RegExp(strippedQuery.split("").join(".*"), "i");
      fuzzyRegexGaps = new RegExp(strippedQuery.split("").join("(.*)"), "i");
    }

    this.siteSettings.forEach((settingsCategory) => {
      let fuzzyMatches = [];

      const siteSettings = settingsCategory.siteSettings.filter((item) => {
        if (opts.onlyOverridden && !item.get("overridden")) {
          return false;
        }
        if (pluginFilter && item.plugin !== pluginFilter) {
          return false;
        }
        if (filter) {
          const setting = item.get("setting").toLowerCase();
          let filterResult =
            setting.includes(filter) ||
            setting.replace(/_/g, " ").includes(filter) ||
            item.get("description").toLowerCase().includes(filter) ||
            (item.get("keywords") || []).any((keyword) =>
              keyword
                .replace(/_/g, " ")
                .toLowerCase()
                .includes(filter.replace(/_/g, " "))
            ) ||
            (item.get("value") || "").toString().toLowerCase().includes(filter);
          if (!filterResult && fuzzyRegex && fuzzyRegex.test(setting)) {
            // Tightens up fuzzy search results a bit.
            const fuzzySearchLimiter = 25;
            const strippedSetting = setting.replace(/[^a-z0-9]/gi, "");
            if (
              strippedSetting.length <=
              strippedQuery.length + fuzzySearchLimiter
            ) {
              const gapResult = strippedSetting.match(fuzzyRegexGaps);
              if (gapResult) {
                item.weight = gapResult.filter((gap) => gap !== "").length;
              }
              fuzzyMatches.push(item);
            }
          }
          return filterResult;
        } else {
          return true;
        }
      });

      if (fuzzyMatches.length > 0) {
        siteSettings.pushObjects(fuzzyMatches);
      }

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
    // and ordered by their gap count asc.
    return settings.sort((a, b) => {
      return (a.weight || 0) - (b.weight || 0);
    });
  }
}
