import { click, getRootElement, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import BoardsColumnSettings from "discourse/plugins/boards/discourse/components/modal/boards-column-settings";
import BoardsFabricators from "discourse/plugins/boards/discourse/lib/fabricators";

const CATEGORY_ID = 12345;
const CATEGORY_NAME = "Unvisited category";

module("Integration | Component | BoardsColumnSettings", function (hooks) {
  setupRenderingTest(hooks);

  test("loads the destination category without writing to frozen form data", async function (assert) {
    this.site.set("lazy_load_categories", true);
    this.owner.lookup("service:modal").containerElement = getRootElement();
    const fabricators = new BoardsFabricators(this.owner);
    this.model = {
      board: fabricators.board(),
      column: fabricators.column(),
    };
    this.model.column.move_to_category_id = CATEGORY_ID;
    pretender.get("/categories/find", () =>
      response({ categories: [{ id: CATEGORY_ID, name: CATEGORY_NAME }] })
    );

    await render(
      <template><BoardsColumnSettings @model={{this.model}} /></template>
    );
    await click(".show-advanced");

    assert
      .dom(".category-chooser .select-kit-header")
      .includesText(CATEGORY_NAME);
  });
});
