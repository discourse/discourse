import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";

function buildUser(overrides = {}) {
  return {
    id: 1,
    username: "eviltrout",
    avatar_template: "/images/avatar.png",
    ...overrides,
  };
}

module("Integration | ui-kit | DUserAvatar", function (hooks) {
  setupRenderingTest(hooks);

  test("renders an anchor wrapping an avatar image", async function (assert) {
    const user = buildUser();
    await render(<template><DUserAvatar @user={{user}} /></template>);

    assert.dom("a").exists();
    assert.dom("a img.avatar").exists();
  });

  test("derives the link href from the user", async function (assert) {
    const user = buildUser({ username: "eviltrout" });
    await render(<template><DUserAvatar @user={{user}} /></template>);

    assert.dom("a").hasAttribute("href", "/u/eviltrout");
  });

  test("@href overrides the derived URL", async function (assert) {
    const user = buildUser();
    await render(
      <template><DUserAvatar @user={{user}} @href="/custom/path" /></template>
    );

    assert.dom("a").hasAttribute("href", "/custom/path");
  });

  test("hides the link from screen readers by default", async function (assert) {
    const user = buildUser();
    await render(<template><DUserAvatar @user={{user}} /></template>);

    assert.dom("a").hasAria("hidden", "true").hasAttribute("tabindex", "-1");
  });

  test("@ariaLabel disables the default hiding and labels the link", async function (assert) {
    const user = buildUser();
    await render(
      <template>
        <DUserAvatar
          @user={{user}}
          @ariaHidden={{false}}
          @ariaLabel="View profile"
        />
      </template>
    );

    assert
      .dom("a")
      .doesNotHaveAria("hidden")
      .hasAria("label", "View profile")
      .hasAttribute("tabindex", "0");
  });

  test("@size is applied to the rendered avatar image", async function (assert) {
    const user = buildUser();
    await render(
      <template><DUserAvatar @user={{user}} @size={{45}} /></template>
    );

    assert
      .dom("a img.avatar")
      .hasAttribute("width", "45")
      .hasAttribute("height", "45");
  });

  test("@lazy adds loading=lazy on the avatar image", async function (assert) {
    const user = buildUser();
    await render(
      <template><DUserAvatar @user={{user}} @lazy={{true}} /></template>
    );

    assert.dom("a img.avatar").hasAttribute("loading", "lazy");
  });

  test("@avatarClasses are forwarded onto the avatar image", async function (assert) {
    const user = buildUser();
    await render(
      <template>
        <DUserAvatar @user={{user}} @avatarClasses="custom-flair" />
      </template>
    );

    assert.dom("a img.avatar.custom-flair").exists();
  });

  test("exposes the data-user-card hook for the popover", async function (assert) {
    const user = buildUser({ username: "eviltrout" });
    await render(<template><DUserAvatar @user={{user}} /></template>);

    assert.dom("a").hasAttribute("data-user-card", "eviltrout");
  });
});
