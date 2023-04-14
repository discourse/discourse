import Component from "@ember/component";
import cookie from "discourse/lib/cookie";
import { schedule } from "@ember/runloop";

export default Component.extend({
  didInsertElement() {
    this._super(...arguments);

    const prefillUsername = $("#hidden-login-form input[name=username]").val();
    if (prefillUsername) {
      this.set("loginName", prefillUsername);
      this.set(
        "loginPassword",
        $("#hidden-login-form input[name=password]").val()
      );
    } else if (cookie("email")) {
      this.set("loginName", cookie("email"));
    }

    schedule("afterRender", () => {
      $(
        "#login-account-password, #login-account-name, #login-second-factor"
      ).keydown((e) => {
        if (e.key === "Enter") {
          this.action();
        }
      });
    });
  },
});
