import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DirectoryItemUserFieldValue from "discourse/components/directory-item-user-field-value";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | DirectoryItemUserFieldValue",
  function (hooks) {
    setupRenderingTest(hooks);

    const column = { user_field_id: 1 };

    function itemWithValue(value) {
      return { user: { user_fields: { 1: { value, searchable: false } } } };
    }

    test("keeps the minus sign of negative numbers", async function (assert) {
      const item = itemWithValue([-10]);

      await render(
        <template>
          <DirectoryItemUserFieldValue @column={{column}} @item={{item}} />
        </template>
      );

      assert
        .dom(".directory-table__value--user-field")
        .hasText("-10", "shows the negative number");
    });

    test("shows 0 rather than a dash", async function (assert) {
      const item = itemWithValue([0]);

      await render(
        <template>
          <DirectoryItemUserFieldValue @column={{column}} @item={{item}} />
        </template>
      );

      assert
        .dom(".directory-table__value--user-field")
        .hasText("0", "shows the zero");
    });

    test("replaces dashes in text values with spaces", async function (assert) {
      const item = itemWithValue(["blue-green"]);

      await render(
        <template>
          <DirectoryItemUserFieldValue @column={{column}} @item={{item}} />
        </template>
      );

      assert
        .dom(".directory-table__value--user-field")
        .hasText("blue green", "keeps the existing text formatting");
    });
  }
);
