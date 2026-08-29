import { click, doubleClick, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockRow from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-row";

const ENTRY = {
  name: "heading",
  displayName: "Heading",
  icon: "heading",
  description: "A section title.",
  thumbnail: null,
};

module(
  "Integration | discourse-wireframe | Component | block-row",
  function (hooks) {
    setupRenderingTest(hooks);

    test("names the row by displayName and describes it by its visible description", async function (assert) {
      await render(<template><BlockRow @entry={{ENTRY}} /></template>);

      assert.dom(".wireframe-block-row").hasAttribute("role", "option");
      assert.dom(".wireframe-block-row").hasAttribute("aria-label", "Heading");
      assert.dom(".wireframe-block-row__name").hasText("Heading");
      assert
        .dom(".wireframe-block-row__description")
        .hasText("A section title.");

      const describedBy = document
        .querySelector(".wireframe-block-row")
        .getAttribute("aria-describedby");
      assert
        .dom(`#${describedBy}`)
        .hasClass(
          "wireframe-block-row__description",
          "the visible description is the accessible one"
        );
    });

    test("activates on click by default, and only on the configured event otherwise", async function (assert) {
      let activated = [];
      const onActivate = (entry) => activated.push(entry.name);

      await render(
        <template>
          <BlockRow @entry={{ENTRY}} @onActivate={{onActivate}} />
        </template>
      );
      await click(".wireframe-block-row");
      assert.deepEqual(activated, ["heading"]);

      activated = [];
      await render(
        <template>
          <BlockRow
            @entry={{ENTRY}}
            @onActivate={{onActivate}}
            @activateOn="dblclick"
          />
        </template>
      );
      await click(".wireframe-block-row");
      assert.deepEqual(activated, [], "a single click is not an activation");
      await doubleClick(".wireframe-block-row");
      assert.deepEqual(activated, ["heading"]);
    });

    test("passes attributes through to the row element", async function (assert) {
      await render(
        <template><BlockRow @entry={{ENTRY}} data-test-row="yes" /></template>
      );
      assert.dom(".wireframe-block-row").hasAttribute("data-test-row", "yes");
      assert
        .dom(".wireframe-block-row")
        .hasAttribute("data-block-name", "heading");
    });
  }
);
