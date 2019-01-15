export default Ember.Service.extend({
  settings: null,

  init() {
    this._super(...arguments);
    this.set("settings", {});
  },

  registerSettings(themeId, settingsObject) {
    this.get("settings")[themeId] = settingsObject;
  },

  getSetting(themeId, settingsKey) {
    return this.get(`settings.${themeId}.${settingsKey}`);
  },

  getObjectForTheme(themeId) {
    return this.get(`settings.${themeId}`);
  }
});
