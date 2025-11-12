import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | select-kit/user-chooser", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("displays usernames", async function (assert) {
    this.set("value", ["bob", "martin"]);

    await render(<template><UserChooser @value={{this.value}} /></template>);

    assert.strictEqual(this.subject.header().name(), "bob,martin");
  });

  test("can remove a username", async function (assert) {
    this.set("value", ["bob", "martin"]);

    await render(<template><UserChooser @value={{this.value}} /></template>);

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

    await render(
      <template><UserChooser @options={{this.options}} /></template>
    );

    await this.subject.expand();
    assert.strictEqual(this.subject.rowByIndex(0).value(), "foo");
    assert.strictEqual(this.subject.rowByIndex(1).value(), "bar");
  });
});
