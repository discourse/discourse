import Component from "@ember/component";
import BufferedContent from "discourse/mixins/buffered-content";
import SiteSetting from "admin/models/site-setting";
import SettingComponent from "admin/mixins/setting-component";
import showModal from "discourse/lib/show-modal";
import AboutRoute from "discourse/routes/about";

export default Component.extend(BufferedContent, SettingComponent, {
  updateExistingUsers: null,

  _save() {
    const setting = this.buffered;
    return SiteSetting.update(setting.get("setting"), setting.get("value"), {
      updateExistingUsers: this.updateExistingUsers
    });
  },

  actions: {
    update() {
      const defaultCategoriesSettings = [
        "default_categories_watching",
        "default_categories_tracking",
        "default_categories_muted",
        "default_categories_watching_first_post"
      ];
      const key = this.buffered.get("setting");

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

            controller.set("onClose", () => {
              this.updateExistingUsers = controller.updateExistingUsers;
              this.send("save");
            });
          });
      } else {
        this.send("save");
      }
    }
  }
});
