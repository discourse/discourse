import componentTest from "helpers/component-test";
moduleForComponent("value-list", { integration: true });

componentTest("functionality", {
  template: '{{value-list values=values inputType="array"}}',
  test(assert) {
    assert.ok(this.$(".values .value").length === 0, "it has no values");
    assert.ok(this.$("input").length, "it renders the input");
    assert.ok(
      this.$(".btn-primary[disabled]").length,
      "it is disabled with no value"
    );

    fillIn("input", "eviltrout");
    andThen(() => {
      assert.ok(
        !this.$(".btn-primary[disabled]").length,
        "it isn't disabled anymore"
      );
    });

    click(".btn-primary");
    andThen(() => {
      assert.equal(this.$(".values .value").length, 1, "it adds the value");
      assert.equal(this.$("input").val(), "", "it clears the input");
      assert.ok(
        this.$(".btn-primary[disabled]").length,
        "it is disabled again"
      );
      assert.equal(this.get("values"), "eviltrout", "it appends the value");
    });

    click(".value .btn-small");
    andThen(() => {
      assert.ok(this.$(".values .value").length === 0, "it removes the value");
    });
  }
});

componentTest("with string delimited values", {
  template: "{{value-list values=valueString}}",
  beforeEach() {
    this.set("valueString", "hello\nworld");
  },

  test(assert) {
    assert.equal(this.$(".values .value").length, 2);

    fillIn("input", "eviltrout");
    click(".btn-primary");

    andThen(() => {
      assert.equal(this.$(".values .value").length, 3);
      assert.equal(this.get("valueString"), "hello\nworld\neviltrout");
    });
  }
});

componentTest("with array values", {
  template: '{{value-list values=valueArray inputType="array"}}',
  beforeEach() {
    this.set("valueArray", ["abc", "def"]);
  },

  test(assert) {
    assert.equal(this.$(".values .value").length, 2);

    fillIn("input", "eviltrout");
    click(".btn-primary");

    andThen(() => {
      assert.equal(this.$(".values .value").length, 3);
      assert.deepEqual(this.get("valueArray"), ["abc", "def", "eviltrout"]);
    });
  }
});
