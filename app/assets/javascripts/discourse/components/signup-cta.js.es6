import { later } from "@ember/runloop";
import Component from "@ember/component";
export default Component.extend({
  action: "showCreateAccount",

  actions: {
    neverShow() {
      this.keyValueStore.setItem("anon-cta-never", "t");
      this.session.set("showSignupCta", false);
    },
    hideForSession() {
      this.session.set("hideSignupCta", true);
      this.keyValueStore.setItem("anon-cta-hidden", new Date().getTime());
      later(
        () => this.session.set("showSignupCta", false),
        20 * 1000
      );
    }
  },

  _turnOffIfHidden: Ember.on("willDestroyElement", function() {
    if (this.session.get("hideSignupCta")) {
      this.session.set("showSignupCta", false);
    }
  })
});
