import { hash } from "@ember/helper";
import { findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import DSelectFont from "discourse/ui-kit/select/recipes/fonts/d-select-font";

/** Listed out of order, so sorting shows. */
const FONTS = [
  { value: "times_new_roman", name: "Times New Roman" },
  { value: "arial", name: "Arial" },
];

module(
  "Integration | ui-kit | select | recipes | DSelectFont",
  function (hooks) {
    setupRenderingTest(hooks);

    test("fonts: lists the fonts by name, each in its own typeface", async function (assert) {
      const noop = () => {};

      await render(
        <template>
          <DSelectFont @fonts={{FONTS}} @onChange={{noop}} @value="arial" />
        </template>
      );

      assert.dom(".d-select").hasAttribute("data-name", "Arial");
      assert
        .dom(".d-select")
        .hasClass(
          "body-font-arial",
          "the held font's typeface is on the field"
        );

      await new DSelect(".d-select").open();

      assert.deepEqual(
        findAll("[role='option']").map((row) => row.dataset.name),
        ["Arial", "Times New Roman"],
        "sorted by name"
      );
      assert
        .dom(
          "[role='option'][data-value='times_new_roman'] .body-font-times-new-roman"
        )
        .hasText("Times New Roman", "each name is drawn in its font");
    });

    test("fonts: reports the picked font's value", async function (assert) {
      const changes = [];
      const onChange = (value) => changes.push(value);

      await render(
        <template>
          <DSelectFont @fonts={{FONTS}} @onChange={{onChange}} @value="arial" />
        </template>
      );
      await new DSelect(".d-select").select("times_new_roman");

      assert.deepEqual(changes, ["times_new_roman"]);
    });

    test("fonts: is named Font unless the caller's texts name it", async function (assert) {
      const noop = () => {};

      await render(
        <template>
          <DSelectFont @fonts={{FONTS}} @onChange={{noop}} @value="arial" />
          <DSelectFont
            class="named"
            @fonts={{FONTS}}
            @onChange={{noop}}
            @texts={{hash ariaLabel="Heading font"}}
            @value="arial"
          />
        </template>
      );

      assert
        .dom(".d-select:not(.named) [role='combobox']")
        .hasAria("label", "Font");
      assert
        .dom(".d-select.named [role='combobox']")
        .hasAria("label", "Heading font");
    });

    test("fonts: keeps the old picker's name for its customizations", async function (assert) {
      const noop = () => {};

      await render(
        <template>
          <DSelectFont @fonts={{FONTS}} @onChange={{noop}} @value="arial" />
        </template>
      );

      assert.dom(".d-select").hasClass("font-selector");
    });
  }
);
