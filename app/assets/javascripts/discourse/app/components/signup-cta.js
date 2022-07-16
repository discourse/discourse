import Component from "@ember/component";
import discourseLater from "discourse-common/lib/later";
import { on } from "@ember/object/evented";

export default Component.extend({
  action: "showCreateAccount",

  actions: {
    neverShow() {
      this.keyValueStore.setItem("anon-cta-never", "t");
      this.session.set("showSignupCta", false);
    },
    hideForSession() {
      this.session.set("hideSignupCta", true);
      this.keyValueStore.setItem("anon-cta-hidden", Date.now());
      discourseLater(() => this.session.set("showSignupCta", false), 20 * 1000);
    },
  },

  _turnOffIfHidden: on("willDestroyElement", function () {
    if (this.session.get("hideSignupCta")) {
      this.session.set("showSignupCta", false);
    }
  }),
});
