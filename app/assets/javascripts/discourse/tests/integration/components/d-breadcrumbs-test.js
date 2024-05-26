import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Component | DBreadcrumbsContainer and DBreadcrumbsItem",
  function (hooks) {
    setupRenderingTest(hooks);

    test("it renders a DBreadcrumbsContainer with multiple DBreadcrumbsItems", async function (assert) {
      await render(hbs`
      <DBreadcrumbsContainer />
      <DBreadcrumbsItem as |linkClass|>
        <LinkTo @route="admin" class={{linkClass}}>
          {{i18n "admin_title"}}
        </LinkTo>
      </DBreadcrumbsItem>
      <DBreadcrumbsItem as |linkClass|>
        <LinkTo @route="about" class={{linkClass}}>
          {{i18n "about.simple_title"}}
        </LinkTo>
      </DBreadcrumbsItem>
  `);

      assert
        .dom(".d-breadcrumbs .d-breadcrumbs__item .d-breadcrumbs__link")
        .exists({ count: 2 });
    });

    test("it renders a DBreadcrumbsItem with additional link and item classes", async function (assert) {
      await render(hbs`
      <DBreadcrumbsContainer @additionalLinkClasses="some-class" @additionalItemClasses="other-class" />
      <DBreadcrumbsItem as |linkClass|>
        <LinkTo @route="admin" class={{linkClass}}>
          {{i18n "admin_title"}}
        </LinkTo>
      </DBreadcrumbsItem>
  `);

      assert.dom(".d-breadcrumbs .d-breadcrumbs__item.other-class").exists();
      assert
        .dom(
          ".d-breadcrumbs .d-breadcrumbs__item .d-breadcrumbs__link.some-class"
        )
        .exists();
    });

    test("it renders multiple DBreadcrumbsContainer elements with the same DBreadcrumbsItem links", async function (assert) {
      await render(hbs`
      <DBreadcrumbsContainer />
      <DBreadcrumbsContainer />
      <DBreadcrumbsItem as |linkClass|>
        <LinkTo @route="admin" class={{linkClass}}>
          {{i18n "admin_title"}}
        </LinkTo>
      </DBreadcrumbsItem>
  `);

      assert.dom(".d-breadcrumbs").exists({ count: 2 });
      assert.dom(".d-breadcrumbs .d-breadcrumbs__item").exists({ count: 2 });
    });
  }
);
