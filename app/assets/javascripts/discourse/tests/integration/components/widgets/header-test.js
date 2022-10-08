import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | Widget | header", function (hooks) {
  setupRenderingTest(hooks);

  test("rendering basics", async function (assert) {
    await render(hbs`<MountWidget @widget="header" />`);

    assert.ok(exists("header.d-header"));
    assert.ok(exists("#site-logo"));
  });

  test("sign up / login buttons", async function (assert) {
    this.owner.unregister("service:current-user");
    this.set("args", { canSignUp: true });
    this.set("showCreateAccount", () => (this.signupShown = true));
    this.set("showLogin", () => (this.loginShown = true));

    await render(hbs`
      <MountWidget
        @widget="header"
        @showCreateAccount={{this.showCreateAccount}}
        @showLogin={{this.showLogin}}
        @args={{this.args}}
      />
    `);

    assert.ok(exists("button.sign-up-button"));
    assert.ok(exists("button.login-button"));

    await click("button.sign-up-button");
    assert.ok(this.signupShown);

    await click("button.login-button");
    assert.ok(this.loginShown);
  });

  test("anon when login required", async function (assert) {
    this.owner.unregister("service:current-user");
    this.set("args", { canSignUp: true });
    this.set("showCreateAccount", () => (this.signupShown = true));
    this.set("showLogin", () => (this.loginShown = true));
    this.siteSettings.login_required = true;

    await render(hbs`
      <MountWidget
        @widget="header"
        @showCreateAccount={{this.showCreateAccount}}
        @showLogin={{this.showLogin}}
        @args={{this.args}}
      />
    `);

    assert.ok(exists("button.login-button"));
    assert.ok(exists("button.sign-up-button"));
    assert.ok(!exists("#search-button"));
    assert.ok(!exists("#toggle-hamburger-menu"));
  });

  test("logged in when login required", async function (assert) {
    this.set("args", { canSignUp: true });
    this.set("showCreateAccount", () => (this.signupShown = true));
    this.set("showLogin", () => (this.loginShown = true));
    this.siteSettings.login_required = true;

    await render(hbs`
      <MountWidget
        @widget="header"
        @showCreateAccount={{this.showCreateAccount}}
        @showLogin={{this.showLogin}}
        @args={{this.args}}
      />
    `);

    assert.ok(!exists("button.login-button"));
    assert.ok(!exists("button.sign-up-button"));
    assert.ok(exists("#search-button"));
    assert.ok(exists("#toggle-hamburger-menu"));
    assert.ok(exists("#current-user"));
  });
});
