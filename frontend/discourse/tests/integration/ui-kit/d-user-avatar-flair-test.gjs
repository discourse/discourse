import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { resetFlair } from "discourse/lib/avatar-flair";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DUserAvatarFlair from "discourse/ui-kit/d-user-avatar-flair";
import I18n, { i18n } from "discourse-i18n";

function setupSiteGroups(that) {
  that.site.groups = [
    {
      id: AUTO_GROUPS.admins.id,
      name: "admins",
      flair_url: "bars",
      flair_bg_color: "CC000A",
      flair_color: "FFFFFA",
    },
    {
      id: AUTO_GROUPS.staff.id,
      name: "staff",
      flair_url: "bars",
      flair_bg_color: "CC0005",
      flair_color: "FFFFF5",
    },
    {
      id: AUTO_GROUPS.trust_level_1.id,
      name: "trust_level_1",
      flair_url: "dice-one",
      flair_bg_color: "CC0001",
      flair_color: "FFFFF1",
    },
    {
      id: AUTO_GROUPS.trust_level_2.id,
      name: "trust_level_2",
      flair_url: "dice-two",
      flair_bg_color: "CC0002",
      flair_color: "FFFFF2",
    },
  ];
}

module("Integration | ui-kit | DUserAvatarFlair", function (hooks) {
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

    await render(<template><DUserAvatarFlair @user={{this.args}} /></template>);

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

    await render(<template><DUserAvatarFlair @user={{this.args}} /></template>);

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

    await render(<template><DUserAvatarFlair @user={{this.args}} /></template>);

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

    await render(<template><DUserAvatarFlair @user={{this.args}} /></template>);

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

    await render(<template><DUserAvatarFlair @user={{this.args}} /></template>);

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

    await render(<template><DUserAvatarFlair @user={{this.args}} /></template>);

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

    await render(<template><DUserAvatarFlair @user={{this.args}} /></template>);

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

    await render(<template><DUserAvatarFlair @user={{this.args}} /></template>);

    assert.dom(".avatar-flair").doesNotExist("does not render a flair");
  });

  test("bot accounts default to accessible robot flair, including system and zero IDs", async function (assert) {
    const user = tracked({ id: -1201 });
    await render(
      <template><DUserAvatarFlair @user={{user.value}} /></template>
    );

    for (const id of [-1201, -1, 0]) {
      user.value = { id };
      await settled();

      assert
        .dom(".avatar-flair.--bot")
        .exists({ count: 1 }, `one fallback is rendered for user ${id}`);
      assert
        .dom(".avatar-flair .d-icon-robot")
        .exists(`user ${id} has the robot icon`);
      assert
        .dom(".avatar-flair")
        .hasAttribute("role", "img", "the marker has image semantics");
      assert
        .dom(".avatar-flair")
        .hasAttribute(
          "aria-label",
          i18n("user.bot_account"),
          "the marker has a translated accessible name"
        );
      assert
        .dom(".avatar-flair")
        .hasAttribute(
          "title",
          i18n("user.bot_account"),
          "the tooltip is translated"
        );
    }
  });

  test("human accounts and missing or invalid IDs have no bot flair", async function (assert) {
    const user = tracked(undefined);
    await render(
      <template><DUserAvatarFlair @user={{user.value}} /></template>
    );

    for (const value of [
      undefined,
      null,
      {},
      { id: null },
      { id: false },
      { id: "-1201" },
      { id: -1.5 },
      { id: 1, username: "release_bot" },
    ]) {
      user.value = value;
      await settled();
      assert
        .dom(".avatar-flair")
        .doesNotExist(`no bot flair for ${JSON.stringify(value)}`);
    }
  });

  test("AI and configured group flair take precedence over the robot fallback", async function (assert) {
    const user = tracked(undefined);
    await render(
      <template><DUserAvatarFlair @user={{user.value}} /></template>
    );

    for (const flair of [
      { flair_url: "discourse-ai", flair_name: "AI" },
      { flair_url: "shield-halved", flair_name: "Team" },
      { flair_url: "/images/avatar.png", flair_name: "Image" },
      { flair_bg_color: "123456", flair_name: "Background" },
    ]) {
      user.value = { id: -1201, flair_group_id: 42, ...flair };
      await settled();

      assert
        .dom(".avatar-flair")
        .exists({ count: 1 }, "only the configured flair is rendered");
      assert
        .dom(".avatar-flair")
        .hasAttribute(
          "title",
          flair.flair_name,
          "the configured tooltip is preserved"
        );
      assert
        .dom(".avatar-flair.--bot")
        .doesNotExist("configured flair wins over the fallback");
      assert
        .dom(".d-icon-robot")
        .doesNotExist("the robot is not stacked with configured flair");
      if (flair.flair_url === "discourse-ai") {
        assert
          .dom(".d-icon-discourse-ai")
          .exists("the existing AI mark is retained");
      }
    }
  });

  test("resolved automatic group flair takes precedence for bot accounts", async function (assert) {
    setupSiteGroups(this);
    const user = { id: -1, admin: true, flair_group_id: AUTO_GROUPS.admins.id };
    await render(<template><DUserAvatarFlair @user={{user}} /></template>);

    assert
      .dom(".d-icon-bars")
      .exists("the existing automatic flair is retained");
    assert
      .dom(".avatar-flair.--bot")
      .doesNotExist("automatic flair wins over the fallback");
  });

  test("bot accounts fall back when group flair is unset or cannot be resolved", async function (assert) {
    setupSiteGroups(this);
    const user = tracked({ id: -1201, trust_level: 2, flair_group_id: null });
    await render(
      <template><DUserAvatarFlair @user={{user.value}} /></template>
    );

    assert
      .dom(".d-icon-robot")
      .exists("an unset group does not prevent the bot fallback");
    assert
      .dom(".d-icon-dice-two")
      .doesNotExist("unset automatic flair remains disabled");

    user.value = { id: -1201, flair_group_id: 999 };
    await settled();
    assert
      .dom(".d-icon-robot")
      .exists("an unresolved group falls back to the bot icon");
  });

  test("the fallback updates when account identity or AI flair changes", async function (assert) {
    const user = tracked({ id: 1 });
    await render(
      <template><DUserAvatarFlair @user={{user.value}} /></template>
    );
    assert.dom(".avatar-flair").doesNotExist("humans have no default flair");

    user.value = { id: -1201 };
    await settled();
    assert
      .dom(".d-icon-robot")
      .exists("bot identity enables the default flair");

    user.value = {
      id: -1201,
      flair_group_id: 42,
      flair_url: "discourse-ai",
      flair_name: "AI",
    };
    await settled();
    assert.dom(".d-icon-discourse-ai").exists("AI flair replaces the fallback");
    assert.dom(".d-icon-robot").doesNotExist("only one marker remains");

    user.value = { id: 1 };
    await settled();
    assert
      .dom(".avatar-flair")
      .doesNotExist("the fallback is removed for humans");
  });

  test("translated bot labels do not become CSS classes", async function (assert) {
    const translations = I18n.translations[I18n.locale].js.user;
    const originalLabel = translations.bot_account;
    const label = "حساب آلي";
    translations.bot_account = label;

    try {
      const user = { id: -1201 };
      await render(<template><DUserAvatarFlair @user={{user}} /></template>);

      assert
        .dom(".avatar-flair")
        .hasAttribute(
          "title",
          label,
          "the tooltip uses the current translation"
        );
      assert
        .dom(".avatar-flair")
        .hasAttribute(
          "aria-label",
          label,
          "the accessible name uses the current translation"
        );
      assert
        .dom(".avatar-flair")
        .hasClass(
          "avatar-flair-bot",
          "the flair class stays locale-independent"
        );
    } finally {
      translations.bot_account = originalLabel;
    }
  });
});
