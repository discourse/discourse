import { ajax } from "discourse/lib/ajax";
export default Discourse.Route.extend({
  model() {
    return ajax("/about.json").then(result => {
      let activeAdmins = [];
      let activeModerators = [];
      const yearAgo = moment()
        .locale("en")
        .utc()
        .subtract(1, "year");
      result.about.admins.forEach(r => {
        if (moment(r.last_seen_at) > yearAgo) activeAdmins.push(r);
      });
      result.about.moderators.forEach(r => {
        if (moment(r.last_seen_at) > yearAgo) activeModerators.push(r);
      });
      result.about.admins = activeAdmins;
      result.about.moderators = activeModerators;
      return result.about;
    });
  },

  titleToken() {
    return I18n.t("about.simple_title");
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
