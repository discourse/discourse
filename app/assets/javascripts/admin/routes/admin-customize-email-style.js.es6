import EmailStyle from "admin/models/email-style";
import { ajax } from "discourse/lib/ajax";

export default Ember.Route.extend({
  model() {
    return ajax("/admin/customize/email_style.json").then(json => {
      return EmailStyle.create(json.email_style);
    });
  },

  redirect() {
    this.transitionTo("adminCustomizeEmailStyle.edit", "html");
  }
});
