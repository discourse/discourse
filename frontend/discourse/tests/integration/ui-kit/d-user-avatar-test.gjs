import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";

module("Integration | ui-kit | DUserAvatar", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.user = {
      username: "eviltrout",
      avatar_template: "/letter_avatar_proxy/v4/letter/e/8797f3/{size}.png",
    };
  });

  test("is hidden from screen readers by default", async function (assert) {
    const user = this.user;

    await render(<template><DUserAvatar @user={{user}} /></template>);

    assert
      .dom("a[data-user-card='eviltrout']")
      .hasAttribute(
        "aria-hidden",
        "true",
        "avatars are usually paired with usernames, so the link is redundant for screen readers"
      )
      .hasAttribute("tabindex", "-1", "the hidden link is not focusable")
      .doesNotHaveAttribute("aria-label");
  });

  test("@ariaHidden={{false}} keeps the link accessible", async function (assert) {
    const user = this.user;

    await render(
      <template><DUserAvatar @ariaHidden={{false}} @user={{user}} /></template>
    );

    assert
      .dom("a[data-user-card='eviltrout']")
      .doesNotHaveAttribute("aria-hidden")
      .hasAttribute("tabindex", "0")
      .hasAttribute("aria-label", "eviltrout's profile");
  });

  test("@ariaLabel keeps the link accessible and overrides the label", async function (assert) {
    const user = this.user;

    await render(
      <template>
        <DUserAvatar @ariaLabel="Robin Ward" @user={{user}} />
      </template>
    );

    assert
      .dom("a[data-user-card='eviltrout']")
      .doesNotHaveAttribute("aria-hidden")
      .hasAttribute("tabindex", "0")
      .hasAttribute("aria-label", "Robin Ward");
  });
});
