import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import { withSilencedDeprecationsAsync } from "discourse-common/lib/deprecated";

function paste(element, text) {
  let e = new Event("paste");
  e.clipboardData = { getData: () => text };
  element.dispatchEvent(e);
}

module("Integration | Component | user-selector", function (hooks) {
  setupRenderingTest(hooks);

  test("pasting a list of usernames", async function (assert) {
    this.set("usernames", "evil,trout");

    await withSilencedDeprecationsAsync(
      "discourse.user-selector-component",
      async () => {
        await render(
          hbs`<UserSelector @usernames={{this.usernames}} class="test-selector" />`
        );
      }
    );

    let element = query(".test-selector");

    assert.strictEqual(this.get("usernames"), "evil,trout");
    paste(element, "zip,zap,zoom");
    assert.strictEqual(this.get("usernames"), "evil,trout,zip,zap,zoom");
    paste(element, "evil,abc,abc,abc");
    assert.strictEqual(this.get("usernames"), "evil,trout,zip,zap,zoom,abc");

    this.set("usernames", "");
    paste(element, "names with spaces");
    assert.strictEqual(this.get("usernames"), "names,with,spaces");

    this.set("usernames", null);
    paste(element, "@eviltrout,@codinghorror sam");
    assert.strictEqual(this.get("usernames"), "eviltrout,codinghorror,sam");

    this.set("usernames", null);
    paste(element, "eviltrout\nsam\ncodinghorror");
    assert.strictEqual(this.get("usernames"), "eviltrout,sam,codinghorror");
  });

  test("excluding usernames", async function (assert) {
    this.set("usernames", "mark");
    this.set("excludedUsernames", ["jeff", "sam", "robin"]);

    await withSilencedDeprecationsAsync(
      "discourse.user-selector-component",
      async () => {
        await render(
          hbs`<UserSelector @usernames={{this.usernames}} @excludedUsernames={{this.excludedUsernames}} class="test-selector" />`
        );
      }
    );

    let element = query(".test-selector");
    paste(element, "roman,penar,jeff,robin");
    assert.strictEqual(this.get("usernames"), "mark,roman,penar");
  });
});
