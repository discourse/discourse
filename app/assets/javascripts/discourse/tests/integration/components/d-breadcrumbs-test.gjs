import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DBreadcrumbsContainer from "discourse/components/d-breadcrumbs-container";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module(
  "Component | DBreadcrumbsContainer and DBreadcrumbsItem",
  function (hooks) {
    setupRenderingTest(hooks);

    test("it renders a DBreadcrumbsContainer with multiple DBreadcrumbsItems", async function (assert) {
      await render(<template>
        <DBreadcrumbsContainer />
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem @path="/about" @label={{i18n "about.simple_title"}} />
      </template>);

      assert
        .dom(".d-breadcrumbs .d-breadcrumbs__item .d-breadcrumbs__link")
        .exists({ count: 2 });
    });

    test("it renders a DBreadcrumbsItem with additional link and item classes", async function (assert) {
      await render(<template>
        <DBreadcrumbsContainer
          @additionalLinkClasses="some-class"
          @additionalItemClasses="other-class"
        />
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      </template>);

      assert.dom(".d-breadcrumbs .d-breadcrumbs__item.other-class").exists();
      assert
        .dom(
          ".d-breadcrumbs .d-breadcrumbs__item .d-breadcrumbs__link.some-class"
        )
        .exists();
    });

    test("it renders multiple DBreadcrumbsContainer elements with the same DBreadcrumbsItem links", async function (assert) {
      await render(<template>
        <DBreadcrumbsContainer />
        <DBreadcrumbsContainer />
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      </template>);

      assert.dom(".d-breadcrumbs").exists({ count: 2 });
      assert.dom(".d-breadcrumbs .d-breadcrumbs__item").exists({ count: 2 });
    });
  }
);
