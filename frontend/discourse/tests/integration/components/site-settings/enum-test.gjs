import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import Enum from "discourse/admin/components/site-settings/enum";
import SiteSetting from "discourse/admin/models/site-setting";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

class State {
  @tracked value = "simple";
}

module("Integration | Component | SiteSettings | Enum", function (hooks) {
  setupRenderingTest(hooks);

  test("reports the picked value and follows @value", async function (assert) {
    const state = new State();
    const setting = SiteSetting.create({
      setting: "tag_style",
      type: "enum",
      valid_values: [
        { name: "Simple", value: "simple" },
        { name: "Box", value: "box" },
      ],
    });
    const changes = [];
    const changeValue = (value) => {
      changes.push(value);
      state.value = value;
    };

    await render(
      <template>
        <Enum
          @changeValueCallback={{changeValue}}
          @setting={{setting}}
          @value={{state.value}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().selectRowByValue("box");

    assert.deepEqual(changes, ["box"], "reports the picked value");

    state.value = "simple";
    await settled();

    assert.strictEqual(
      selectKit().header().value(),
      "simple",
      "renders a value set by the caller"
    );
  });
});
