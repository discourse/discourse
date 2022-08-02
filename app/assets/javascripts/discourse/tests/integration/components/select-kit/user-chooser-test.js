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
});
