import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import GroupList from "discourse/admin/components/site-settings/group-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";

module("Integration | Component | SiteSettings | GroupList", function (hooks) {
  setupRenderingTest(hooks);

  test("holds, locks and offers groups with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.site.groups = [
      { id: 0, name: "everyone" },
      { id: 1, name: "Donuts" },
      { id: 2, name: "Cheese cake" },
      { id: 3, name: "Muffins" },
    ];
    const setting = {
      disallowed_groups: "0",
      mandatory_values: "1|2",
      value: "1|3",
    };
    const changes = [];
    const changeValue = (value) => changes.push(value);

    await render(
      <template>
        <GroupList
          @changeValueCallback={{changeValue}}
          @label="My groups"
          @setting={{setting}}
          @value="1|3"
        />
      </template>
    );

    assert.dom(".d-select").hasAttribute("data-name", "Donuts,Muffins");
    assert
      .dom(".d-select__chip[data-value='1']")
      .hasClass("--locked", "a mandatory group can't be removed");
    assert
      .dom(".d-select__chip[data-value='3']")
      .doesNotHaveClass("--locked", "the other groups can");

    await dSelect(".d-select").open();
    assert
      .dom("[role='option'][data-value='0']")
      .doesNotExist("a disallowed group is not offered");

    await dSelect(".d-select").select(2);
    assert.deepEqual(changes, ["1|3|2"], "reports the new list");
  });

  test("keeps everyone stored as everyone with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.siteSettings.granular_anonymous_and_logged_in_groups_permissions = true;
    this.site.groups = [
      { id: 0, name: "everyone" },
      { id: 1, name: "Donuts" },
      { id: 5, name: "logged_in_users" },
      { id: 11, name: "trust_level_1" },
    ];
    const setting = { value: "0|11" };
    const changes = [];
    const changeValue = (value) => changes.push(value);

    await render(
      <template>
        <GroupList
          @changeValueCallback={{changeValue}}
          @label="My groups"
          @setting={{setting}}
          @value="0|11"
        />
      </template>
    );

    assert
      .dom(".d-select")
      .hasAttribute(
        "data-name",
        "logged_in_users,trust_level_1",
        "shows logged_in_users in place of everyone"
      );

    await dSelect(".d-select").open();
    assert
      .dom("[role='option'][data-value='0']")
      .doesNotExist("everyone is not offered beside logged_in_users");

    await dSelect(".d-select").select(1);
    assert.deepEqual(changes, ["0|11|1"], "stores everyone back as everyone");
  });
});
