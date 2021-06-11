import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, exists } from "discourse/tests/helpers/qunit-helpers";
import { click } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | Widget | header", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("rendering basics", {
    template: hbs`{{mount-widget widget="header"}}`,
    test(assert) {
      assert.ok(exists("header.d-header"));
      assert.ok(exists("#site-logo"));
    },
  });

  componentTest("sign up / login buttons", {
    template: hbs`
      {{mount-widget
        widget="header"
        showCreateAccount=showCreateAccount
        showLogin=showLogin
        args=args
      }}
    `,
    anonymous: true,

    beforeEach() {
      this.set("args", { canSignUp: true });
      this.set("showCreateAccount", () => (this.signupShown = true));
      this.set("showLogin", () => (this.loginShown = true));
    },

    async test(assert) {
      assert.ok(exists("button.sign-up-button"));
      assert.ok(exists("button.login-button"));

      await click("button.sign-up-button");
      assert.ok(this.signupShown);

      await click("button.login-button");
      assert.ok(this.loginShown);
    },
  });

  componentTest("anon when login required", {
    template: hbs`
      {{mount-widget
        widget="header"
        showCreateAccount=showCreateAccount
        showLogin=showLogin
        args=args
      }}
    `,
    anonymous: true,

    beforeEach() {
      this.set("args", { canSignUp: true });
      this.set("showCreateAccount", () => (this.signupShown = true));
      this.set("showLogin", () => (this.loginShown = true));
      this.siteSettings.login_required = true;
    },

    test(assert) {
      assert.ok(exists("button.login-button"));
      assert.ok(exists("button.sign-up-button"));
      assert.ok(!exists("#search-button"));
      assert.ok(!exists("#toggle-hamburger-menu"));
    },
  });

  componentTest("logged in when login required", {
    template: hbs`
      {{mount-widget
        widget="header"
        showCreateAccount=showCreateAccount
        showLogin=showLogin
        args=args
      }}
    `,

    beforeEach() {
      this.set("args", { canSignUp: true });
      this.set("showCreateAccount", () => (this.signupShown = true));
      this.set("showLogin", () => (this.loginShown = true));
      this.siteSettings.login_required = true;
    },

    test(assert) {
      assert.ok(!exists("button.login-button"));
      assert.ok(!exists("button.sign-up-button"));
      assert.ok(exists("#search-button"));
      assert.ok(exists("#toggle-hamburger-menu"));
      assert.ok(exists("#current-user"));
    },
  });
});
