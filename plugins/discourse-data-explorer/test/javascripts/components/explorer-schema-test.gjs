import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ExplorerSchema from "discourse/plugins/discourse-data-explorer/discourse/components/explorer-schema";

const schema = {
  posts: [
    {
      column_name: "id",
      data_type: "serial",
      primary: true,
      notes: "primary key",
      havetypeinfo: true,
    },
    {
      column_name: "raw",
      data_type: "text",
      column_desc: "The raw Markdown that the user entered into the composer.",
      havepopup: true,
      havetypeinfo: true,
    },
  ],
  categories: [
    {
      column_name: "id",
      data_type: "serial",
      primary: true,
      notes: "primary key",
      havetypeinfo: true,
    },
    {
      column_name: "name",
      data_type: "varchar(50)",
      havetypeinfo: false,
    },
  ],
};

module("Component | ExplorerSchema", function (hooks) {
  setupRenderingTest(hooks);

  test("will automatically convert to lowercase", async function (assert) {
    this.setProperties({ schema });

    await render(
      <template><ExplorerSchema @schema={{this.schema}} /></template>
    );

    await fillIn(`.schema-search input`, "Cat");

    assert.dom(".schema-table").exists();

    await fillIn(`.schema-search input`, "NotExist");

    assert.dom(".schema-table").doesNotExist();
  });

  test("can be hidden and shown again", async function (assert) {
    this.setProperties({
      schema,
      hideSchema: false,
      updateHideSchema: (value) => this.set("hideSchema", value),
    });

    await render(
      <template>
        <ExplorerSchema
          @schema={{this.schema}}
          @hideSchema={{this.hideSchema}}
          @updateHideSchema={{this.updateHideSchema}}
        />
      </template>
    );

    assert.dom(".schema-search__input").exists("search input is visible");
    assert
      .dom(".schema__toggle.--collapse")
      .hasAttribute("aria-label", "Hide schema");

    await click(".schema__toggle.--collapse");

    assert.dom(".schema-search__input").doesNotExist("search input is hidden");
    assert.dom(".schema-table").doesNotExist("schema tables are hidden");
    assert
      .dom(".schema__toggle.--expand")
      .hasAttribute("aria-label", "Show schema");

    await click(".schema__toggle.--expand");

    assert.dom(".schema-search__input").exists("search input is visible again");
    assert.dom(".schema-table").exists("schema tables are visible again");
  });
});
