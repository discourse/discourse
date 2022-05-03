import Component from "@ember/component";
import { later } from "@ember/runloop";
import { on } from "@ember/object/evented";
import { inject as service } from "@ember/service";

export default Component.extend({
  keyValueStore: service(),

  action: "showCreateAccount",

  actions: {
    neverShow() {
      this.keyValueStore.setItem("anon-cta-never", "t");
      this.session.set("showSignupCta", false);
    },
    hideForSession() {
      this.session.set("hideSignupCta", true);
      this.keyValueStore.setItem("anon-cta-hidden", Date.now());
      later(() => this.session.set("showSignupCta", false), 20 * 1000);
    },
  },

  _turnOffIfHidden: on("willDestroyElement", function () {
    if (this.session.get("hideSignupCta")) {
      this.session.set("showSignupCta", false);
    }
  }),
});
