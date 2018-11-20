import showModal from "discourse/lib/show-modal";

export default Ember.Component.extend({
  actions: {
    showUploadModal({ value, setting }) {
      showModal("admin-uploaded-image-list", {
        admin: true,
        title: `admin.site_settings.${setting.setting}.title`,
        model: { value, setting }
      }).setProperties({
        save: v => this.set("value", v)
      });
    }
  }
});
