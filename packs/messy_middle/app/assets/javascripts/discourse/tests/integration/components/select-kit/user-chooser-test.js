import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | select-kit/user-chooser", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("displays usernames", async function (assert) {
    this.set("value", ["bob", "martin"]);

    await render(hbs`<UserChooser @value={{this.value}} />`);

    assert.strictEqual(this.subject.header().name(), "bob,martin");
  });

  test("can remove a username", async function (assert) {
    this.set("value", ["bob", "martin"]);

    await render(hbs`<UserChooser @value={{this.value}} />`);

    await this.subject.expand();
    await this.subject.deselectItemByValue("bob");
    assert.strictEqual(this.subject.header().name(), "martin");
  });

  test("can display default search results", async function (assert) {
    this.set("options", {
      customSearchOptions: {
        defaultSearchResults: [{ username: "foo" }, { username: "bar" }],
      },
    });

    await render(hbs`<UserChooser @options={{this.options}} />`);

    await this.subject.expand();
    assert.strictEqual(this.subject.rowByIndex(0).value(), "foo");
    assert.strictEqual(this.subject.rowByIndex(1).value(), "bar");
  });
});
