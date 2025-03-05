import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminSearch from "admin/components/admin-search";

module("Integration | Component | AdminSearch", function (hooks) {
  setupRenderingTest(hooks);

  test("remembers last toggled filters, and opens filter controls by default", async function (assert) {
    await render(<template><AdminSearch /></template>);

    assert.dom(".admin-search__filters").exists();
    assert
      .dom(".admin-search__filter.--page .admin-search__filter-item.is-active")
      .exists();
    assert
      .dom(
        ".admin-search__filter.--setting .admin-search__filter-item.is-active"
      )
      .exists();
    assert
      .dom(".admin-search__filter.--theme .admin-search__filter-item.is-active")
      .exists();
    assert
      .dom(
        ".admin-search__filter.--component .admin-search__filter-item.is-active"
      )
      .exists();
    assert
      .dom(
        ".admin-search__filter.--report .admin-search__filter-item.is-active"
      )
      .exists();

    await render(<template><AdminSearch /></template>);

    // TODO (martin) test that clicking a couple of the filters is remembered
  });

  // test("filters different types of search results", async function (assert) {});
});
