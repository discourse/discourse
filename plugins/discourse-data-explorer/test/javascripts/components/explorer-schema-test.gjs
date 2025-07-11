import { fillIn, render } from "@ember/test-helpers";
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

module("Data Explorer Plugin | Component | explorer-schema", function (hooks) {
  setupRenderingTest(hooks);

  test("will automatically convert to lowercase", async function (assert) {
    const self = this;

    this.setProperties({
      schema,
      hideSchema: false,
      updateHideSchema: () => {},
    });

    await render(
      <template>
        <ExplorerSchema
          @schema={{self.schema}}
          @hideSchema={{self.hideSchema}}
          @updateHideSchema={{self.updateHideSchema}}
        />
      </template>
    );

    await fillIn(`.schema-search input`, "Cat");

    assert.dom(".schema-table").exists();

    await fillIn(`.schema-search input`, "NotExist");

    assert.dom(".schema-table").doesNotExist();
  });
});
