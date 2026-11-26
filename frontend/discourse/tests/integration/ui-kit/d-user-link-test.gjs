import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DUserLink from "discourse/ui-kit/d-user-link";
import { i18n } from "discourse-i18n";

module("Integration | ui-kit | DUserLink", function (hooks) {
  setupRenderingTest(hooks);

  test("links to the profile of @username", async function (assert) {
    await render(
      <template>
        <DUserLink class="author" @username="Sam">Sam</DUserLink>
      </template>
    );

    assert
      .dom("a.author")
      .hasText("Sam", "the block is the link text")
      .hasAttribute("href", "/u/sam", "the path uses the lowercase username")
      .hasAttribute("data-user-card", "Sam")
      .hasAttribute("tabindex", "0")
      .hasAttribute(
        "aria-label",
        i18n("user.profile_possessive", { username: "Sam" })
      )
      .doesNotHaveAttribute("aria-hidden");
  });

  test("prefers @href, then the path of @user", async function (assert) {
    const user = { username: "eviltrout", path: "/u/eviltrout/summary" };

    await render(
      <template>
        <DUserLink class="with-href" @href="/custom" @user={{user}} />
        <DUserLink class="with-user" @user={{user}} />
      </template>
    );

    assert.dom(".with-href").hasAttribute("href", "/custom");
    assert
      .dom(".with-user")
      .hasAttribute("href", "/u/eviltrout/summary")
      .hasAttribute("data-user-card", "eviltrout", "@user names the card");
  });

  test("@ariaLabel replaces the default label", async function (assert) {
    await render(
      <template><DUserLink @ariaLabel="Custom" @username="sam" /></template>
    );

    assert.dom("a").hasAttribute("aria-label", "Custom");
  });

  test("@ariaHidden hides the link from assistive technology", async function (assert) {
    await render(
      <template>
        <DUserLink @ariaHidden={{true}} @ariaLabel="Ignored" @username="sam" />
      </template>
    );

    assert
      .dom("a")
      .hasAttribute("aria-hidden", "true")
      .hasAttribute("tabindex", "-1", "the link leaves the tab order")
      .doesNotHaveAttribute("aria-label", "a hidden link has no label");
  });
});

module("Integration | ui-kit | DUserLink | anonymous", function (hooks) {
  setupRenderingTest(hooks, { anonymous: true });

  test("does not link hidden profiles for anonymous users", async function (assert) {
    this.siteSettings.hide_user_profiles_from_public = true;

    await render(<template><DUserLink @username="sam" /></template>);

    assert
      .dom("a")
      .hasClass("non-clickable")
      .doesNotHaveAttribute("href", "the profile is not linked");
  });
});
