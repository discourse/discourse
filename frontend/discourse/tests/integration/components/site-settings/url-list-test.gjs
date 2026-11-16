import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import UrlList from "discourse/admin/components/site-settings/url-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | SiteSettings | UrlList", function (hooks) {
  setupRenderingTest(hooks);

  test("reports changes as a newline-joined string and follows @value", async function (assert) {
    const settingValue = tracked("https://a.com\nhttps://b.com");
    const changes = [];
    const changeValue = (value) => {
      changes.push(value);
      settingValue.value = value;
    };

    await render(
      <template>
        <UrlList
          @changeValueCallback={{changeValue}}
          @value={{settingValue.value}}
        />
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

    settingValue.value = "https://z.com";
    await settled();

    assert
      .dom(".values .value-input")
      .hasValue("https://z.com", "renders a value set by the caller");
  });
});
