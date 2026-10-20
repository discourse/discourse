import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { forceMobile } from "discourse/lib/mobile";
import { selectControl } from "discourse/lib/select-control";
import ComboBox from "discourse/select-kit/components/combo-box";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSelect from "discourse/ui-kit/select/d-select";

const ITEMS = [
  { id: 1, name: "One" },
  { id: 2, name: "Two" },
];

/** Asserts that focusing `control` puts keyboard focus on it, inside the select. */
function assertFocusable(assert, control, root) {
  control.focus();
  assert.strictEqual(document.activeElement, control, "it takes focus");
  assert.true(root.contains(control), "it belongs to the select");
}

module("Integration | Lib | select-control", function (hooks) {
  setupRenderingTest(hooks);

  test("returns the header of a select-kit select", async function (assert) {
    await render(
      <template>
        <div class="host"><ComboBox @content={{ITEMS}} @value={{1}} /></div>
      </template>
    );

    const header = find(".select-kit-header");
    assert.strictEqual(
      selectControl(find(".select-kit")),
      header,
      "from the root"
    );
    assert.strictEqual(
      selectControl(find(".host")),
      header,
      "from a container"
    );
    assertFocusable(assert, header, find(".select-kit"));
  });

  test("returns the query input of a typeahead DSelect", async function (assert) {
    await render(
      <template>
        <div class="host"><DSelect @items={{ITEMS}} @value={{1}} /></div>
      </template>
    );

    const input = find(".d-select .d-select__input");
    assert.strictEqual(
      selectControl(find(".d-select")),
      input,
      "from the root"
    );
    assert.strictEqual(selectControl(find(".host")), input, "from a container");
    assertFocusable(assert, input, find(".d-select"));
  });

  for (const variant of ["button", "static"]) {
    test(`returns the root of a ${variant} DSelect`, async function (assert) {
      await render(
        <template>
          <div class="host">
            <DSelect @items={{ITEMS}} @value={{1}} @variant={{variant}} />
          </div>
        </template>
      );

      const root = find(".d-select");
      assert.strictEqual(selectControl(root), root, "from the root");
      assert.strictEqual(
        selectControl(find(".host")),
        root,
        "from a container"
      );
      assertFocusable(assert, root, root);
    });
  }

  test("returns the root of a typeahead DSelect on mobile, whose query input lives in the modal", async function (assert) {
    forceMobile();

    await render(
      <template>
        <div class="host"><DSelect @items={{ITEMS}} @value={{1}} /></div>
      </template>
    );

    const root = find(".d-select");
    assert.dom(".d-select .d-select__input").doesNotExist();
    assert.strictEqual(selectControl(root), root, "from the root");
    assert.strictEqual(selectControl(find(".host")), root, "from a container");
  });

  test("returns null when there is no select", async function (assert) {
    await render(
      <template>
        <div class="host"><input /></div>
      </template>
    );

    assert.strictEqual(selectControl(find(".host")), null);
  });
});
