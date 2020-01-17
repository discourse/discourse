import { isEmpty } from "@ember/utils";
import { alias } from "@ember/object/computed";
import Controller from "@ember/controller";
import discourseDebounce from "discourse/lib/debounce";
import { observes } from "discourse-common/utils/decorators";

export default Controller.extend({
  filter: null,
  allSiteSettings: alias("model"),
  visibleSiteSettings: null,
  onlyOverridden: false,

  filterContentNow(category) {
    // If we have no content, don't bother filtering anything
    if (!!isEmpty(this.allSiteSettings)) return;

    let filter;
    if (this.filter) {
      filter = this.filter.toLowerCase().trim();
    }

    if ((!filter || 0 === filter.length) && !this.onlyOverridden) {
      this.set("visibleSiteSettings", this.allSiteSettings);
      if (this.categoryNameKey === "all_results") {
        this.transitionToRoute("adminSiteSettings");
      }
      return;
    }

    const all = {
      nameKey: "all_results",
      name: I18n.t("admin.site_settings.categories.all_results"),
      siteSettings: []
    };
    const matchesGroupedByCategory = [all];

    const matches = [];
    this.allSiteSettings.forEach(settingsCategory => {
      const siteSettings = settingsCategory.siteSettings.filter(item => {
        if (this.onlyOverridden && !item.get("overridden")) return false;
        if (filter) {
          const setting = item.get("setting").toLowerCase();
          return (
            setting.includes(filter) ||
            setting.replace(/_/g, " ").includes(filter) ||
            item
              .get("description")
              .toLowerCase()
              .includes(filter) ||
            (item.get("value") || "").toLowerCase().includes(filter)
          );
        } else {
          return true;
        }
      });
      if (siteSettings.length > 0) {
        matches.pushObjects(siteSettings);
        matchesGroupedByCategory.pushObject({
          nameKey: settingsCategory.nameKey,
          name: I18n.t(
            "admin.site_settings.categories." + settingsCategory.nameKey
          ),
          siteSettings,
          count: siteSettings.length
        });
      }
    });

    all.siteSettings.pushObjects(matches.slice(0, 30));
    all.hasMore = matches.length > 30;
    all.count = all.hasMore ? "30+" : matches.length;

    this.set("visibleSiteSettings", matchesGroupedByCategory);
    this.transitionToRoute(
      "adminSiteSettingsCategory",
      category || "all_results"
    );
  },

  @observes("filter", "onlyOverridden", "model")
  filterContent: discourseDebounce(function() {
    if (this._skipBounce) {
      this.set("_skipBounce", false);
    } else {
      this.filterContentNow();
    }
  }, 250),

  actions: {
    clearFilter() {
      this.setProperties({ filter: "", onlyOverridden: false });
    },

    toggleMenu() {
      $(".admin-detail").toggleClass("mobile-closed mobile-open");
    }
  }
});
