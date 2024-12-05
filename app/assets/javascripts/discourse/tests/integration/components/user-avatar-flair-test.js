import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { resetFlair } from "discourse/lib/avatar-flair";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function setupSiteGroups(that) {
  that.site.groups = [
    {
      id: 1,
      name: "admins",
      flair_url: "bars",
      flair_bg_color: "CC000A",
      flair_color: "FFFFFA",
    },
    {
      id: 2,
      name: "staff",
      flair_url: "bars",
      flair_bg_color: "CC0005",
      flair_color: "FFFFF5",
    },
    {
      id: 3,
      name: "trust_level_1",
      flair_url: "dice-one",
      flair_bg_color: "CC0001",
      flair_color: "FFFFF1",
    },
    {
      id: 4,
      name: "trust_level_2",
      flair_url: "dice-two",
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
      flair_group_id: 12,
    });
    setupSiteGroups(this);

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.dom(".avatar-flair").exists("has the tag");
    assert.dom("svg.d-icon-bars").exists("has the svg icon");
    assert.dom(".avatar-flair").hasStyle({
      backgroundColor: "rgb(204, 0, 10)",
      color: "rgb(255, 255, 250)",
    });
  });

  test("avatar flair for moderator user with fallback to staff", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: true,
      trust_level: 2,
      flair_group_id: 12,
    });
    setupSiteGroups(this);

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.dom(".avatar-flair").exists("has the tag");
    assert.dom("svg.d-icon-bars").exists("has the svg icon");
    assert.dom(".avatar-flair").hasStyle({
      backgroundColor: "rgb(204, 0, 5)",
      color: "rgb(255, 255, 245)",
    });
  });

  test("avatar flair for trust level", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: false,
      trust_level: 2,
      flair_group_id: 12,
    });
    setupSiteGroups(this);

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.dom(".avatar-flair").exists("has the tag");
    assert.dom("svg.d-icon-dice-two").exists("has the svg icon");
    assert.dom(".avatar-flair").hasStyle({
      backgroundColor: "rgb(204, 0, 2)",
      color: "rgb(255, 255, 242)",
    });
  });

  test("avatar flair for trust level when set to none", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: false,
      trust_level: 2,
      flair_group_id: null,
    });
    setupSiteGroups(this);

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.dom(".avatar-flair").doesNotExist("does not render a flair");
  });

  test("avatar flair for trust level with fallback", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: false,
      trust_level: 3,
      flair_group_id: 13,
    });
    setupSiteGroups(this);

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.dom(".avatar-flair").exists("has the tag");
    assert.dom("svg.d-icon-dice-two").exists("has the svg icon");
    assert.dom(".avatar-flair").hasStyle({
      backgroundColor: "rgb(204, 0, 2)",
      color: "rgb(255, 255, 242)",
    });
  });

  test("avatar flair for login-required site, before login", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: false,
      trust_level: 3,
      flair_group_id: 13,
    });
    // Groups not serialized for anon on login_required
    this.site.groups = undefined;

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.dom(".avatar-flair").doesNotExist("does not render a flair");
  });

  test("avatar flair for primary group flair", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: false,
      trust_level: 3,
      flair_name: "Band Geeks",
      flair_url: "xmark",
      flair_bg_color: "123456",
      flair_color: "B0B0B0",
      flair_group_id: 41,
      primary_group_name: "Band Geeks",
    });
    setupSiteGroups(this);

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.dom(".avatar-flair").exists("has the tag");
    assert.dom("svg.d-icon-xmark").exists("has the svg icon");
    assert.dom(".avatar-flair").hasStyle({
      backgroundColor: "rgb(18, 52, 86)",
      color: "rgb(176, 176, 176)",
    });
  });

  test("user-avatar-flair for user with no flairs", async function (assert) {
    this.set("args", {
      admin: false,
      moderator: false,
      trust_level: 1,
      flair_group_id: 11,
    });

    await render(hbs`<UserAvatarFlair @user={{this.args}} />`);

    assert.dom(".avatar-flair").doesNotExist("does not render a flair");
  });
});
