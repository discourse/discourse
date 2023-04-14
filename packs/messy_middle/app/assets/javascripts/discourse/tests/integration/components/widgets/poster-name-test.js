import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | Widget | poster-name", function (hooks) {
  setupRenderingTest(hooks);

  test("basic rendering", async function (assert) {
    this.set("args", {
      username: "eviltrout",
      usernameUrl: "/u/eviltrout",
      name: "Robin Ward",
      user_title: "Trout Master",
    });

    await render(
      hbs`<MountWidget @widget="poster-name" @args={{this.args}} />`
    );

    assert.ok(exists(".names"));
    assert.ok(exists("span.username"));
    assert.ok(exists('a[data-user-card="eviltrout"]'));
    assert.strictEqual(query(".username a").innerText, "eviltrout");
    assert.strictEqual(query(".user-title").innerText, "Trout Master");
  });

  test("extra classes and glyphs", async function (assert) {
    this.set("args", {
      username: "eviltrout",
      usernameUrl: "/u/eviltrout",
      staff: true,
      admin: true,
      moderator: true,
      new_user: true,
      primary_group_name: "fish",
    });

    await render(
      hbs`<MountWidget @widget="poster-name" @args={{this.args}} />`
    );

    assert.ok(exists("span.staff"));
    assert.ok(exists("span.admin"));
    assert.ok(exists("span.moderator"));
    assert.ok(exists(".d-icon-shield-alt"));
    assert.ok(exists("span.new-user"));
    assert.ok(exists("span.group--fish"));
  });

  test("disable display name on posts", async function (assert) {
    this.siteSettings.display_name_on_posts = false;
    this.set("args", { username: "eviltrout", name: "Robin Ward" });

    await render(
      hbs`<MountWidget @widget="poster-name" @args={{this.args}} />`
    );

    assert.ok(!exists(".full-name"));
  });

  test("doesn't render a name if it's similar to the username", async function (assert) {
    this.siteSettings.prioritize_username_in_ux = true;
    this.siteSettings.display_name_on_posts = true;
    this.set("args", { username: "eviltrout", name: "evil-trout" });

    await render(
      hbs`<MountWidget @widget="poster-name" @args={{this.args}} />`
    );

    assert.ok(!exists(".second"));
  });
});
