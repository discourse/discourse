import { componentTest } from "wizard/test/helpers/component-test";
import { moduleForComponent } from "ember-qunit";
import { click, fillIn } from "@ember/test-helpers";

moduleForComponent("invite-list", { integration: true });

componentTest("can add users", {
  template: `{{invite-list field=field}}`,

  beforeEach() {
    this.set("field", {});
  },

  async test(assert) {
    assert.ok(
      document.querySelectorAll(".users-list .invite-list-user").length === 0,
      "no users at first"
    );
    assert.ok(
      document.querySelectorAll(".new-user .invalid").length === 0,
      "not invalid at first"
    );

    const firstVal = JSON.parse(this.get("field.value"));
    assert.strictEqual(firstVal.length, 0, "empty JSON at first");

    assert.ok(
      this.get("field.warning"),
      "it has a warning since no users were added"
    );

    await click(".add-user");
    assert.ok(
      document.querySelectorAll(".users-list .invite-list-user").length === 0,
      "doesn't add a blank user"
    );
    assert.ok(document.querySelectorAll(".new-user .invalid").length === 1);

    await fillIn(".invite-email", "eviltrout@example.com");
    await click(".add-user");

    assert.ok(
      document.querySelectorAll(".users-list .invite-list-user").length === 1,
      "adds the user"
    );
    assert.ok(document.querySelectorAll(".new-user .invalid").length === 0);

    const val = JSON.parse(this.get("field.value"));
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

    assert.ok(
      document.querySelectorAll(".users-list .invite-list-user").length === 1,
      "can't add the same user twice"
    );
    assert.ok(document.querySelectorAll(".new-user .invalid").length === 1);

    await fillIn(".invite-email", "not-an-email");
    await click(".add-user");

    assert.ok(
      document.querySelectorAll(".users-list .invite-list-user").length === 1,
      "won't add an invalid email"
    );
    assert.ok(document.querySelectorAll(".new-user .invalid").length === 1);

    await click(".invite-list .invite-list-user:nth-of-type(1) .remove-user");
    assert.ok(
      document.querySelectorAll(".users-list .invite-list-user").length === 0,
      "removed the user"
    );
  },
});
