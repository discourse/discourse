import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import { resetFlair } from "discourse/lib/avatar-flair";

function setupSiteGroups(that) {
  that.site.groups = [
    {
      id: 1,
      name: "admins",
      flair_url: "fa-bars",
      flair_bg_color: "CC000A",
      flair_color: "FFFFFA",
    },
    {
      id: 2,
      name: "staff",
      flair_url: "fa-bars",
      flair_bg_color: "CC0005",
      flair_color: "FFFFF5",
    },
    {
      id: 3,
      name: "trust_level_1",
      flair_url: "fa-dice-one",
      flair_bg_color: "CC0001",
      flair_color: "FFFFF1",
    },
    {
      id: 4,
      name: "trust_level_2",
      flair_url: "fa-dice-two",
      flair_bg_color: "CC0002",
      flair_color: "FFFFF2",
    },
  ];
}

module("Integration | Component | user-avatar-flair", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    resetFlair();
  });

  hooks.afterEach(function () {
    resetFlair();
  });

  test("avatar flair for admin user", async function (assert) {
    this.set("args", {
      admin: true,
      moderator: false,
      trust_level: 2,
    });
    setupSiteGroups(this);

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.ok(exists(".avatar-flair"), "it has the tag");
    assert.ok(exists("svg.d-icon-bars"), "it has the svg icon");
    assert.strictEqual(
      query(".avatar-flair").getAttribute("style"),
      "background-color: #CC000A; color: #FFFFFA; ",
      "it has styles"
    );
  });

  test("avatar flair for moderator user with fallback to staff", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: true,
      trust_level: 2,
    });
    setupSiteGroups(this);

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.ok(exists(".avatar-flair"), "it has the tag");
    assert.ok(exists("svg.d-icon-bars"), "it has the svg icon");
    assert.strictEqual(
      query(".avatar-flair").getAttribute("style"),
      "background-color: #CC0005; color: #FFFFF5; ",
      "it has styles"
    );
  });

  test("avatar flair for trust level", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: false,
      trust_level: 2,
    });
    setupSiteGroups(this);

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.ok(exists(".avatar-flair"), "it has the tag");
    assert.ok(exists("svg.d-icon-dice-two"), "it has the svg icon");
    assert.strictEqual(
      query(".avatar-flair").getAttribute("style"),
      "background-color: #CC0002; color: #FFFFF2; ",
      "it has styles"
    );
  });

  test("avatar flair for trust level with fallback", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: false,
      trust_level: 3,
    });
    setupSiteGroups(this);

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.ok(exists(".avatar-flair"), "it has the tag");
    assert.ok(exists("svg.d-icon-dice-two"), "it has the svg icon");
    assert.strictEqual(
      query(".avatar-flair").getAttribute("style"),
      "background-color: #CC0002; color: #FFFFF2; ",
      "it has styles"
    );
  });

  test("avatar flair for login-required site, before login", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: false,
      trust_level: 3,
    });
    // Groups not serialized for anon on login_required
    this.site.groups = undefined;

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.ok(!exists(".avatar-flair"), "it does not render a flair");
  });

  test("avatar flair for primary group flair", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: false,
      trust_level: 3,
      flair_name: "Band Geeks",
      flair_url: "fa-times",
      flair_bg_color: "123456",
      flair_color: "B0B0B0",
      primary_group_name: "Band Geeks",
    });
    setupSiteGroups(this);

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.ok(exists(".avatar-flair"), "it has the tag");
    assert.ok(exists("svg.d-icon-times"), "it has the svg icon");
    assert.strictEqual(
      query(".avatar-flair").getAttribute("style"),
      "background-color: #123456; color: #B0B0B0; ",
      "it has styles"
    );
  });

  test("user-avatar-flair for user with no flairs", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: false,
      trust_level: 1,
    });

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.ok(!exists(".avatar-flair"), "it does not render a flair");
  });
});
