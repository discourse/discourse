import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminFlagItem from "discourse/admin/components/admin-flag-item";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | AdminFlagItem", function (hooks) {
  setupRenderingTest(hooks);

  function createFlag(overrides = {}) {
    return {
      id: 1001,
      name: "colliding",
      name_key: "custom_colliding",
      description: "custom flag",
      enabled: true,
      is_used: false,
      system: false,
      ...overrides,
    };
  }

  test("custom flag is editable", async function (assert) {
    this.flag = createFlag();

    await render(
      <template>
        <DMenus />
        <AdminFlagItem @flag={{this.flag}} />
      </template>
    );

    assert
      .dom(".admin-flag-item__edit")
      .doesNotHaveAttribute("disabled", "the edit button is enabled");
    assert
      .dom(".d-table__overview-link")
      .exists("the name links to the edit route");
  });

  test("system flag is not editable", async function (assert) {
    this.flag = createFlag({ id: 3, name_key: "off_topic", system: true });

    await render(
      <template>
        <DMenus />
        <AdminFlagItem @flag={{this.flag}} />
      </template>
    );

    assert
      .dom(".admin-flag-item__edit")
      .hasAttribute("disabled", "", "the edit button is disabled");
    assert
      .dom(".d-table__overview-link")
      .doesNotExist("the name is not a link");
  });

  // Editability follows the serialized `system` flag rather than a hardcoded id
  // list, so a system flag missing from SYSTEM_FLAG_IDS stays locked.
  test("system flag absent from SYSTEM_FLAG_IDS is not editable", async function (assert) {
    this.flag = createFlag({ id: 11, name_key: "unlisted", system: true });

    await render(
      <template>
        <DMenus />
        <AdminFlagItem @flag={{this.flag}} />
      </template>
    );

    assert
      .dom(".admin-flag-item__edit")
      .hasAttribute("disabled", "", "the edit button is disabled");
    assert
      .dom(".d-table__overview-link")
      .doesNotExist("the name is not a link");
  });
});
