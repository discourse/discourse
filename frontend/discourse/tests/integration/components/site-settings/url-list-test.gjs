import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import UrlList from "discourse/admin/components/site-settings/url-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

class State {
  @tracked value = "https://a.com\nhttps://b.com";
}

module("Integration | Component | SiteSettings | UrlList", function (hooks) {
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
        <UrlList @changeValueCallback={{changeValue}} @value={{state.value}} />
      </template>
    );

    await selectKit().expand();
    await selectKit().fillInFilter("https://c.com");
    await selectKit().keyboard("Enter");

    assert.deepEqual(
      changes,
      ["https://a.com\nhttps://b.com\nhttps://c.com"],
      "reports the new list through the callback"
    );
    assert.dom(".values .value").exists({ count: 3 }, "shows the added url");

    state.value = "https://z.com";
    await settled();

    assert
      .dom(".values .value-input")
      .hasValue("https://z.com", "renders a value set by the caller");
  });
});
