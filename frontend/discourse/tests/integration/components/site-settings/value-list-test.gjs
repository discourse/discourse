import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteSettingValueList from "discourse/admin/components/site-settings/value-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

class State {
  @tracked value = "a\nb";
}

module("Integration | Component | SiteSettings | ValueList", function (hooks) {
  setupRenderingTest(hooks);

  test("reports changes as a newline-joined string and follows @value", async function (assert) {
    const state = new State();
    const changes = [];
    const changeValue = (value) => {
      changes.push(value);
      state.value = value;
    };

    await render(
      <template>
        <SiteSettingValueList
          @changeValueCallback={{changeValue}}
          @value={{state.value}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().fillInFilter("c");
    await selectKit().keyboard("Enter");

    assert.deepEqual(
      changes,
      ["a\nb\nc"],
      "reports the new list through the callback"
    );
    assert.dom(".values .value").exists({ count: 3 }, "shows the added value");

    state.value = "z";
    await settled();

    assert
      .dom(".values .value-input")
      .hasValue("z", "renders a value set by the caller");
  });
});
