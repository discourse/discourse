import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import Badge from "discourse/models/badge";
import User from "discourse/models/user";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// TODO (glimmer-post-stream) remove this test when removing the widget post stream code
module("Integration | Component | Widget | poster-name", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.glimmer_post_stream_mode = "disabled";
  });

  test("basic rendering", async function (assert) {
    const args = {
      username: "eviltrout",
      usernameUrl: "/u/eviltrout",
      name: "Robin Ward",
      user_title: "Trout Master",
    };

    await render(
      <template><MountWidget @widget="poster-name" @args={{args}} /></template>
    );

    assert.dom(".names").exists();
    assert.dom("span.username").exists();
    assert.dom('a[data-user-card="eviltrout"]').exists();
    assert.dom(".username a").hasText("eviltrout");
    assert.dom(".user-title").hasText("Trout Master");
  });

  test("extra classes and glyphs", async function (assert) {
    const args = {
      username: "eviltrout",
      usernameUrl: "/u/eviltrout",
      staff: true,
      admin: true,
      moderator: true,
      new_user: true,
      primary_group_name: "fish",
    };

    await render(
      <template><MountWidget @widget="poster-name" @args={{args}} /></template>
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
    const args = { username: "eviltrout", name: "Robin Ward" };

    await render(
      <template><MountWidget @widget="poster-name" @args={{args}} /></template>
    );

    assert.dom(".full-name").doesNotExist();
  });

  test("doesn't render a name if it's similar to the username", async function (assert) {
    this.siteSettings.prioritize_username_in_ux = true;
    this.siteSettings.display_name_on_posts = true;
    const args = { username: "eviltrout", name: "evil-trout" };

    await render(
      <template><MountWidget @widget="poster-name" @args={{args}} /></template>
    );

    assert.dom(".second").doesNotExist();
  });

  test("renders badges that are passed in", async function (assert) {
    const args = {
      username: "eviltrout",
      usernameUrl: "/u/eviltrout",
      user: User.create({
        username: "eviltrout",
      }),
      badgesGranted: [
        { id: 1, icon: "heart", slug: "badge1", name: "Badge One" },
        { id: 2, icon: "target", slug: "badge2", name: "Badge Two" },
      ].map((badge) => Badge.createFromJson({ badges: [badge] })[0]),
    };

    await render(
      <template><MountWidget @widget="poster-name" @args={{args}} /></template>
    );

    // Check that the custom CSS classes are set
    assert.dom("span.user-badge-button-badge1").exists();
    assert.dom("span.user-badge-button-badge2").exists();

    // Check that the custom titles are set
    assert.dom("span.user-badge[title*='Badge One']").exists();
    assert.dom("span.user-badge[title*='Badge Two']").exists();

    // Check that the badges link to the correct badge page
    assert
      .dom("a.user-card-badge-link[href='/badges/1/badge1?username=eviltrout']")
      .exists();
    assert
      .dom("a.user-card-badge-link[href='/badges/2/badge2?username=eviltrout']")
      .exists();
  });
});
