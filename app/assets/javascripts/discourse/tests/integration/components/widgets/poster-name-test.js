import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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

    assert.dom(".names").exists();
    assert.dom("span.username").exists();
    assert.dom('a[data-user-card="eviltrout"]').exists();
    assert.dom(".username a").hasText("eviltrout");
    assert.dom(".user-title").hasText("Trout Master");
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

    assert.dom("span.staff").exists();
    assert.dom("span.admin").exists();
    assert.dom("span.moderator").exists();
    assert.dom(".d-icon-shield-halved").exists();
    assert.dom("span.new-user").exists();
    assert.dom("span.group--fish").exists();
  });

  test("disable display name on posts", async function (assert) {
    this.siteSettings.display_name_on_posts = false;
    this.set("args", { username: "eviltrout", name: "Robin Ward" });

    await render(
      hbs`<MountWidget @widget="poster-name" @args={{this.args}} />`
    );

    assert.dom(".full-name").doesNotExist();
  });

  test("doesn't render a name if it's similar to the username", async function (assert) {
    this.siteSettings.prioritize_username_in_ux = true;
    this.siteSettings.display_name_on_posts = true;
    this.set("args", { username: "eviltrout", name: "evil-trout" });

    await render(
      hbs`<MountWidget @widget="poster-name" @args={{this.args}} />`
    );

    assert.dom(".second").doesNotExist();
  });
});
