import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import HorizonSiteSkeleton from "discourse/components/horizon-site-skeleton";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | HorizonSiteSkeleton", function (hooks) {
  setupRenderingTest(hooks);

  test("falls back to placeholder site name and username", async function (assert) {
    await render(<template><HorizonSiteSkeleton /></template>);

    assert
      .dom(".horizon-site-skeleton__name")
      .hasText("your-community", "uses the fallback site name");
    assert
      .dom(".horizon-site-skeleton__avatar")
      .hasText("m", "renders the first letter of the fallback username");
    assert
      .dom(".horizon-site-skeleton__welcome-row h3")
      .hasText("Welcome back,member!", "greets the fallback username");
  });

  test("uses the provided site name and user", async function (assert) {
    const user = { username: "frank" };

    await render(
      <template>
        <HorizonSiteSkeleton @siteName="acme" @user={{user}} />
      </template>
    );

    assert.dom(".horizon-site-skeleton__name").hasText("acme");
    assert
      .dom(".horizon-site-skeleton__avatar .user-profile-avatar")
      .exists("renders the real avatar when a user is provided");
    assert
      .dom(".horizon-site-skeleton__welcome-row h3")
      .hasText("Welcome back,frank!");
    assert.dom(".horizon-site-skeleton__topic-main strong").hasText(
      i18n("horizon_site_skeleton.topic.welcome.title", {
        site_name: "acme",
      }),
      "interpolates the site name into the welcome topic title"
    );
  });

  test("escapes a username containing HTML in the welcome heading", async function (assert) {
    const user = { username: "<img src=x onerror=alert(1)>" };

    await render(<template><HorizonSiteSkeleton @user={{user}} /></template>);

    const heading = document.querySelector(
      ".horizon-site-skeleton__welcome-row h3"
    );
    assert
      .dom("img", heading)
      .doesNotExist("does not inject the username as markup");
    assert
      .dom(".horizon-site-skeleton__welcome-row h3")
      .includesText("<img src=x onerror=alert(1)>", "renders it as text");
  });

  test("is inert decorative chrome", async function (assert) {
    await render(<template><HorizonSiteSkeleton /></template>);

    assert.dom(".horizon-site-skeleton").hasAttribute("aria-hidden", "true");
    assert
      .dom(".horizon-site-skeleton__new-topic")
      .hasText(i18n("horizon_site_skeleton.new_topic"));
  });
});
