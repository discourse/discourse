import { getOwner } from "@ember/owner";
import { trustHTML } from "@ember/template";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import linkifySettingLinks from "discourse/admin/modifiers/linkify-setting-links";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  logIn,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

module("Integration | Modifier | linkify-setting-links", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    logIn(getOwner(this));
    updateCurrentUser({ admin: true });
  });

  test("rewrites a setting link's href to its config page", async function (assert) {
    const description =
      '<a class="site-setting-link" href="/admin/site_settings/category/all_results?filter=title" data-setting-name="title" data-setting-area="about" data-setting-category="required">Title</a>';

    await render(
      <template>
        <div {{linkifySettingLinks description}}>{{trustHTML description}}</div>
      </template>
    );

    assert
      .dom("a.site-setting-link")
      .hasAttribute("href", "/admin/config/about?filter=title");
  });

  test("leaves an unmapped setting link pointing at the all-settings page", async function (assert) {
    const description =
      '<a class="site-setting-link" href="/admin/site_settings/category/all_results?filter=foo" data-setting-name="foo">Foo</a>';

    await render(
      <template>
        <div {{linkifySettingLinks description}}>{{trustHTML description}}</div>
      </template>
    );

    assert
      .dom("a.site-setting-link")
      .hasAttribute(
        "href",
        "/admin/site_settings/category/all_results?filter=foo"
      );
  });
});
