import { click, fillIn, getRootElement, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
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

  test("picks the column icon and color from the style menu", async function (assert) {
    this.owner.lookup("service:modal").containerElement = getRootElement();
    const fabricators = new BoardsFabricators(this.owner);
    this.model = { board: fabricators.board(), column: fabricators.column() };
    pretender.get("/svg-sprite/picker-search", () =>
      response({ icons: [{ id: "anchor" }], has_more: false })
    );

    await render(
      <template><BoardsColumnSettings @model={{this.model}} /></template>
    );
    await click(".discourse-boards-column-style-trigger");

    assert
      .dom(".discourse-boards-column-style-content input[name='color']")
      .exists("shows the color field");
    await click(
      ".discourse-boards-column-style-content [data-icon-id='anchor']"
    );
    assert
      .dom(".discourse-boards-column-style-trigger .d-icon-anchor")
      .exists("previews the picked icon");
  });

  test("focuses the name and rejects a blank one", async function (assert) {
    this.owner.lookup("service:modal").containerElement = getRootElement();
    const fabricators = new BoardsFabricators(this.owner);
    this.model = {
      board: fabricators.board(),
      column: null,
      onSave: () => assert.step("saved"),
    };

    await render(
      <template><BoardsColumnSettings @model={{this.model}} /></template>
    );
    assert.dom("input[name='title']").isFocused("focuses the name input");

    await fillIn("input[name='title']", "   ");
    await click(".discourse-boards-column-settings-modal__save");

    assert
      .dom(".form-kit__errors")
      .includesText(
        i18n("boards.manage.columns.column_title_required"),
        "treats a blank name as missing"
      );
    assert.verifySteps([], "does not save");
  });
});
