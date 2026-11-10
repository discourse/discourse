import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";

module("Integration | ui-kit | Helper | dAvatar", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.prioritize_username_in_ux = false;
    this.siteSettings.enable_names = true;
    this.user = {
      username: "login_name",
      name: "O'Name <&>",
      title: "Moderator",
      avatar_template: "/avatar/{size}.png",
    };
  });

  test("alt is empty by default", async function (assert) {
    const user = this.user;

    await render(<template>{{dAvatar user imageSize="tiny"}}</template>);

    assert.dom("img.avatar").hasAttribute("alt", "");
  });

  test("alt=true uses the display name and leaves the title alone", async function (assert) {
    const user = this.user;

    await render(
      <template>{{dAvatar user alt=true imageSize="tiny"}}</template>
    );

    assert.dom("img.avatar").hasAttribute("alt", user.name);
    assert.dom("img.avatar").hasAttribute("title", "Moderator");
  });

  test("an alt string is escaped as text", async function (assert) {
    const user = this.user;
    const alt = "' onerror='alert(1)";

    await render(
      <template>{{dAvatar user alt=alt imageSize="tiny"}}</template>
    );

    assert.dom("img.avatar").hasAttribute("alt", alt);
    assert
      .dom("img.avatar")
      .doesNotHaveAttribute("onerror", "it cannot break out of the attribute");
  });
});
