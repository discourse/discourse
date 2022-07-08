import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, fillIn, render } from "@ember/test-helpers";
import { count, exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

module("Integration | Component | Wizard | invite-list", function (hooks) {
  setupRenderingTest(hooks);

  test("can add users", async function (assert) {
    this.set("field", {});

    await render(hbs`<InviteList @field={{this.field}} />`);

    assert.ok(!exists(".users-list .invite-list-user"), "no users at first");
    assert.ok(!exists(".new-user .invalid"), "not invalid at first");

    const firstVal = JSON.parse(this.field.value);
    assert.strictEqual(firstVal.length, 0, "empty JSON at first");

    assert.ok(this.field.warning, "it has a warning since no users were added");

    await click(".add-user");
    assert.ok(
      !exists(".users-list .invite-list-user"),
      "doesn't add a blank user"
    );
    assert.strictEqual(count(".new-user .invalid"), 1);

    await fillIn(".invite-email", "eviltrout@example.com");
    await click(".add-user");

    assert.strictEqual(
      count(".users-list .invite-list-user"),
      1,
      "adds the user"
    );
    assert.ok(!exists(".new-user .invalid"));

    const val = JSON.parse(this.field.value);
    assert.strictEqual(val.length, 1);
    assert.strictEqual(
      val[0].email,
      "eviltrout@example.com",
      "adds the email to the JSON"
    );
    assert.ok(val[0].role.length, "adds the role to the JSON");
    assert.ok(!this.get("field.warning"), "no warning once the user is added");

    await fillIn(".invite-email", "eviltrout@example.com");
    await click(".add-user");

    assert.strictEqual(
      count(".users-list .invite-list-user"),
      1,
      "can't add the same user twice"
    );
    assert.strictEqual(count(".new-user .invalid"), 1);

    await fillIn(".invite-email", "not-an-email");
    await click(".add-user");

    assert.strictEqual(
      count(".users-list .invite-list-user"),
      1,
      "won't add an invalid email"
    );
    assert.strictEqual(count(".new-user .invalid"), 1);

    await click(".invite-list .invite-list-user:nth-of-type(1) .remove-user");
    assert.ok(!exists(".users-list .invite-list-user"), 0, "removed the user");
  });
});
