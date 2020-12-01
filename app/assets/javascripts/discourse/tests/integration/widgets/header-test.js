import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click } from "@ember/test-helpers";

discourseModule("Integration | Component | Widget | header", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("rendering basics", {
    template: '{{mount-widget widget="header"}}',
    test(assert) {
      assert.ok(queryAll("header.d-header").length);
      assert.ok(queryAll("#site-logo").length);
    },
  });

  componentTest("sign up / login buttons", {
    template:
      '{{mount-widget widget="header" showCreateAccount=(action "showCreateAccount") showLogin=(action "showLogin") args=args}}',
    anonymous: true,

    beforeEach() {
      this.set("args", { canSignUp: true });
      this.on("showCreateAccount", () => (this.signupShown = true));
      this.on("showLogin", () => (this.loginShown = true));
    },

    async test(assert) {
      assert.ok(queryAll("button.sign-up-button").length);
      assert.ok(queryAll("button.login-button").length);

      await click("button.sign-up-button");
      assert.ok(this.signupShown);

      await click("button.login-button");
      assert.ok(this.loginShown);
    },
  });

  componentTest("anon when login required", {
    template:
      '{{mount-widget widget="header" showCreateAccount=(action "showCreateAccount") showLogin=(action "showLogin") args=args}}',
    anonymous: true,

    beforeEach() {
      this.set("args", { canSignUp: true });
      this.on("showCreateAccount", () => (this.signupShown = true));
      this.on("showLogin", () => (this.loginShown = true));
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
    template:
      '{{mount-widget widget="header" showCreateAccount=(action "showCreateAccount") showLogin=(action "showLogin") args=args}}',

    beforeEach() {
      this.set("args", { canSignUp: true });
      this.on("showCreateAccount", () => (this.signupShown = true));
      this.on("showLogin", () => (this.loginShown = true));
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
