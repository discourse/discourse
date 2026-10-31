import { click, getRootElement, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
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

  test("with the new select controls, a picked user becomes the assignee", async function (assert) {
    this.siteSettings.assign_enabled = true;
    this.siteSettings.enable_new_select_controls = true;
    this.owner.lookup("service:modal").containerElement = getRootElement();
    pretender.get("/u/search/users", () =>
      response({
        users: [{ username: "bob", name: "Bob", avatar_template: "/a/{size}" }],
      })
    );
    const fabricators = new BoardsFabricators(this.owner);
    this.model = {
      board: fabricators.board(),
      column: fabricators.column(),
    };
    this.model.column.move_to_assigned = "martin";
    const closeModal = () => {};

    await render(
      <template>
        <BoardsColumnSettings
          @closeModal={{closeModal}}
          @model={{this.model}}
        />
      </template>
    );
    await click(".show-advanced");
    const assignee = dSelect(".d-select.email-group-user-chooser");
    assert
      .dom(assignee.element())
      .hasAttribute("data-value", "martin", "the held assignee is shown");

    await assignee.search("bo");
    await assignee.selectByName("bob");
    assert.dom(assignee.element()).hasAttribute("data-value", "bob");
  });
});
