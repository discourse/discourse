import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import DBreadcrumbsContainer from "discourse/components/d-breadcrumbs-container";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import i18n from "discourse-common/helpers/i18n";

module(
  "Component | DBreadcrumbsContainer and DBreadcrumbsItem",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a DBreadcrumbsContainer with multiple DBreadcrumbsItems", async function (assert) {
      await render(<template>
        <DBreadcrumbsContainer />
        <DBreadcrumbsItem @route="admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem @route="about" @label={{i18n "about.simple_title"}} />
      </template>);

      assert
        .dom(".d-breadcrumbs .d-breadcrumbs__item .d-breadcrumbs__link")
        .exists({ count: 2 });
    });

    test("renders a DBreadcrumbsItem with additional link and item classes", async function (assert) {
      await render(<template>
        <DBreadcrumbsContainer
          @additionalLinkClasses="some-class"
          @additionalItemClasses="other-class"
        />
        <DBreadcrumbsItem @route="admin" @label={{i18n "admin_title"}} />
      </template>);

      assert.dom(".d-breadcrumbs .d-breadcrumbs__item.other-class").exists();
      assert
        .dom(
          ".d-breadcrumbs .d-breadcrumbs__item .d-breadcrumbs__link.some-class"
        )
        .exists();
    });

    test("renders multiple DBreadcrumbsContainer elements with the same DBreadcrumbsItem links", async function (assert) {
      await render(<template>
        <DBreadcrumbsContainer />
        <DBreadcrumbsContainer />
        <DBreadcrumbsItem @route="admin" @label={{i18n "admin_title"}} />
      </template>);

      assert.dom(".d-breadcrumbs").exists({ count: 2 });
      assert.dom(".d-breadcrumbs .d-breadcrumbs__item").exists({ count: 2 });
    });

    test("ignores temporarily invalid/unresolvable routes", async function (assert) {
      class TestState {
        @tracked flag = true;
        @tracked id = 123;
      }

      const testState = new TestState();

      await render(<template>
        <DBreadcrumbsContainer />

        {{#if testState.flag}}
          <DBreadcrumbsItem
            @route="post"
            @model={{testState.id}}
            @label="my post"
          />
        {{else}}
          <DBreadcrumbsItem @route="about" @label="about" />
        {{/if}}
      </template>);

      assert.dom(".d-breadcrumbs a[href='/p/123']").exists();
      assert.dom(".d-breadcrumbs a[href='/about']").doesNotExist();

      testState.flag = false;
      testState.id = null;
      await settled();

      assert.dom(".d-breadcrumbs a[href='/p/123']").doesNotExist();
      assert.dom(".d-breadcrumbs a[href='/about']").exists();
    });
  }
);
