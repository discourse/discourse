import { ajax } from "discourse/lib/ajax";
import Setting from "admin/mixins/setting-object";

const SiteSetting = Discourse.Model.extend(Setting, {});

SiteSetting.reopenClass({
  findAll() {
    return ajax("/admin/site_settings").then(function(settings) {
      // Group the results by category
      const categories = {};
      settings.site_settings.forEach(function(s) {
        if (!categories[s.category]) {
          categories[s.category] = [];
        }
        categories[s.category].pushObject(SiteSetting.create(s));
      });

      return Object.keys(categories).map(function(n) {
        return {
          nameKey: n,
          name: I18n.t("admin.site_settings.categories." + n),
          siteSettings: categories[n]
        };
      });
    });
  },

  update(key, value) {
    const data = {};
    data[key] = value;
    return ajax(`/admin/site_settings/${key}`, { type: "PUT", data });
  }
});

export default SiteSetting;
