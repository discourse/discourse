import { componentTest } from "wizard/test/helpers/component-test";
moduleForComponent("invite-list", { integration: true });

componentTest("can add users", {
  template: `{{invite-list field=field}}`,

  beforeEach() {
    this.set("field", {});
  },

  test(assert) {
    assert.ok(
      this.$(".users-list .invite-list-user").length === 0,
      "no users at first"
    );
    assert.ok(
      this.$(".new-user .invalid").length === 0,
      "not invalid at first"
    );

    const firstVal = JSON.parse(this.get("field.value"));
    assert.equal(firstVal.length, 0, "empty JSON at first");

    assert.ok(
      this.get("field.warning"),
      "it has a warning since no users were added"
    );

    click(".add-user");
    andThen(() => {
      assert.ok(
        this.$(".users-list .invite-list-user").length === 0,
        "doesn't add a blank user"
      );
      assert.ok(this.$(".new-user .invalid").length === 1);
    });

    fillIn(".invite-email", "eviltrout@example.com");
    click(".add-user");

    andThen(() => {
      assert.ok(
        this.$(".users-list .invite-list-user").length === 1,
        "adds the user"
      );
      assert.ok(this.$(".new-user .invalid").length === 0);

      const val = JSON.parse(this.get("field.value"));
      assert.equal(val.length, 1);
      assert.equal(
        val[0].email,
        "eviltrout@example.com",
        "adds the email to the JSON"
      );
      assert.ok(val[0].role.length, "adds the role to the JSON");
      assert.ok(
        !this.get("field.warning"),
        "no warning once the user is added"
      );
    });

    fillIn(".invite-email", "eviltrout@example.com");
    click(".add-user");

    andThen(() => {
      assert.ok(
        this.$(".users-list .invite-list-user").length === 1,
        "can't add the same user twice"
      );
      assert.ok(this.$(".new-user .invalid").length === 1);
    });

    fillIn(".invite-email", "not-an-email");
    click(".add-user");

    andThen(() => {
      assert.ok(
        this.$(".users-list .invite-list-user").length === 1,
        "won't add an invalid email"
      );
      assert.ok(this.$(".new-user .invalid").length === 1);
    });

    click(".invite-list .invite-list-user:eq(0) .remove-user");
    andThen(() => {
      assert.ok(
        this.$(".users-list .invite-list-user").length === 0,
        "removed the user"
      );
    });
  }
});
