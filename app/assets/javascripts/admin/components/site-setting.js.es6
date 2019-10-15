import BufferedContent from "discourse/mixins/buffered-content";
import SiteSetting from "admin/models/site-setting";
import SettingComponent from "admin/mixins/setting-component";
import showModal from "discourse/lib/show-modal";
import AboutRoute from "discourse/routes/about";

export default Ember.Component.extend(BufferedContent, SettingComponent, {
  update(key, value, updateExistingUsers = false) {
    if (updateExistingUsers) {
      return SiteSetting.update(key, value, { updateExistingUsers: true });
    } else {
      return SiteSetting.update(key, value);
    }
  },

  _save(callback) {
    const defaultCategoriesSettings = [
      "default_categories_watching",
      "default_categories_tracking",
      "default_categories_muted",
      "default_categories_watching_first_post"
    ];
    const setting = this.buffered;
    const key = setting.get("setting");
    const value = setting.get("value");

    if (defaultCategoriesSettings.includes(key)) {
      AboutRoute.create()
        .model()
        .then(result => {
          const controller = showModal("site-setting-default-categories", {
            model: {
              count: result.stats.user_count,
              key: key.replace(/_/g, " ")
            },
            admin: true
          });

          controller.setProperties({
            onClose: () => {
              const updateExistingUsers = controller.get("updateExistingUsers");
              if (updateExistingUsers === true) {
                callback(this.update(key, value, true));
              } else if (updateExistingUsers === false) {
                callback(this.update(key, value));
              }
            }
          });
        });
    } else {
      callback(this.update(key, value));
    }
  }
});
