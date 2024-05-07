import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DropdownMenu from "discourse/components/dropdown-menu";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | <DropdownMenu />", function (hooks) {
  setupRenderingTest(hooks);

  test("dropdown menu", async function (assert) {
    await render(<template><DropdownMenu class="test" /></template>);

    assert
      .dom("ul.dropdown-menu.test")
      .exists("it renders the dropdown menu with custom class");
  });

  test("dropdown menu item", async function (assert) {
    await render(<template>
      <DropdownMenu as |dm|><dm.item class="test">test</dm.item></DropdownMenu>
    </template>);

    assert
      .dom("li.dropdown-menu__item.test")
      .exists("it renders the item with custom class")
      .hasText("test");
  });

  test("dropdown menu divider", async function (assert) {
    await render(<template>
      <DropdownMenu as |dm|><dm.divider class="test" /></DropdownMenu>
    </template>);

    assert
      .dom("li.test hr.dropdown-menu__divider")
      .exists("it renders the divider with custom class");
  });
});
