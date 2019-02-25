import { componentTest } from "wizard/test/helpers/component-test";
moduleForComponent("invite-list", { integration: true });

componentTest("can add users", {
  template: `{{invite-list field=field}}`,

  beforeEach() {
    this.set("field", {});
  },

  async test(assert) {
    assert.ok(
      find(".users-list .invite-list-user").length === 0,
      "no users at first"
    );
    assert.ok(find(".new-user .invalid").length === 0, "not invalid at first");

    const firstVal = JSON.parse(this.get("field.value"));
    assert.equal(firstVal.length, 0, "empty JSON at first");

    assert.ok(
      this.get("field.warning"),
      "it has a warning since no users were added"
    );

    await click(".add-user");
    assert.ok(
      find(".users-list .invite-list-user").length === 0,
      "doesn't add a blank user"
    );
    assert.ok(find(".new-user .invalid").length === 1);

    await fillIn(".invite-email", "eviltrout@example.com");
    await click(".add-user");

    assert.ok(
      find(".users-list .invite-list-user").length === 1,
      "adds the user"
    );
    assert.ok(find(".new-user .invalid").length === 0);

    const val = JSON.parse(this.get("field.value"));
    assert.equal(val.length, 1);
    assert.equal(
      val[0].email,
      "eviltrout@example.com",
      "adds the email to the JSON"
    );
    assert.ok(val[0].role.length, "adds the role to the JSON");
    assert.ok(!this.get("field.warning"), "no warning once the user is added");

    await fillIn(".invite-email", "eviltrout@example.com");
    await click(".add-user");

    assert.ok(
      find(".users-list .invite-list-user").length === 1,
      "can't add the same user twice"
    );
    assert.ok(find(".new-user .invalid").length === 1);

    await fillIn(".invite-email", "not-an-email");
    await click(".add-user");

    assert.ok(
      find(".users-list .invite-list-user").length === 1,
      "won't add an invalid email"
    );
    assert.ok(find(".new-user .invalid").length === 1);

    await click(".invite-list .invite-list-user:eq(0) .remove-user");
    assert.ok(
      find(".users-list .invite-list-user").length === 0,
      "removed the user"
    );
  }
});
