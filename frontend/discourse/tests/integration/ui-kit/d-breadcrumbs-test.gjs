import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setPrefix } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DBreadcrumbsContainer from "discourse/ui-kit/d-breadcrumbs-container";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";

module("Integration | ui-kit | DBreadcrumbs", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders a DBreadcrumbsContainer with multiple DBreadcrumbsItems", async function (assert) {
    await render(
      <template>
        <DBreadcrumbsContainer />
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem @label={{i18n "about.simple_title"}} @path="/about" />
      </template>
    );

    assert
      .dom(".d-breadcrumbs .d-breadcrumbs__item .d-breadcrumbs__link")
      .exists({ count: 2 });
  });

  test("it renders a DBreadcrumbsItem with additional link and item classes", async function (assert) {
    await render(
      <template>
        <DBreadcrumbsContainer
          @additionalItemClasses="other-class"
          @additionalLinkClasses="some-class"
        />
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      </template>
    );

    assert.dom(".d-breadcrumbs .d-breadcrumbs__item.other-class").exists();
    assert
      .dom(
        ".d-breadcrumbs .d-breadcrumbs__item .d-breadcrumbs__link.some-class"
      )
      .exists();
  });

  test("separator is rendered on every item except the last", async function (assert) {
    await render(
      <template>
        <DBreadcrumbsContainer />
        <DBreadcrumbsItem @label="Admin" @path="/admin" />
        <DBreadcrumbsItem @label="Backups" @path="/admin/backups" />
        <DBreadcrumbsItem @label="Logs" @path="/admin/backups/logs" />
      </template>
    );

    assert.dom(".d-breadcrumbs li .separator").exists({ count: 2 });
    assert.dom(".d-breadcrumbs li:last-child .separator").doesNotExist();
  });

  test("it renders multiple DBreadcrumbsContainer elements with the same DBreadcrumbsItem links", async function (assert) {
    await render(
      <template>
        <DBreadcrumbsContainer />
        <DBreadcrumbsContainer />
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      </template>
    );

    assert.dom(".d-breadcrumbs").exists({ count: 2 });
    assert.dom(".d-breadcrumbs .d-breadcrumbs__item").exists({ count: 2 });
  });

  module("an item without @route or @path", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.owner.unregister("service:router");
      this.owner.register(
        "service:router",
        class extends Service {
          currentURL = "/admin/plugins/gadgets";
        }
      );
    });

    test("links to the current page", async function (assert) {
      await render(
        <template>
          <DBreadcrumbsContainer />
          <DBreadcrumbsItem @label="Admin" @path="/admin" />
          <DBreadcrumbsItem @label="Gadgets" />
        </template>
      );

      assert
        .dom(".d-breadcrumbs li:first-child .d-breadcrumbs__link")
        .hasAttribute("href", "/admin", "an item with @path links there");
      assert
        .dom(".d-breadcrumbs li:last-child .d-breadcrumbs__link")
        .hasAttribute("href", "/admin/plugins/gadgets");
    });

    test("links to the current page on a subfolder install", async function (assert) {
      setPrefix("/forum");

      await render(
        <template>
          <DBreadcrumbsContainer />
          <DBreadcrumbsItem @label="Gadgets" />
        </template>
      );

      assert
        .dom(".d-breadcrumbs .d-breadcrumbs__link")
        .hasAttribute("href", "/forum/admin/plugins/gadgets");
    });
  });
});
