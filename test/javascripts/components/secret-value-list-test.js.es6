import componentTest from "helpers/component-test";
moduleForComponent("secret-value-list", { integration: true });

componentTest("adding a value", {
  template: "{{secret-value-list values=values}}",

  async test(assert) {
    this.set("values", "firstKey|FirstValue\nsecondKey|secondValue");

    await fillIn(".new-value-input.key", "thirdKey");
    await click(".add-value-btn");

    assert.ok(
      find(".values .value").length === 2,
      "it doesn't add the value to the list if secret is missing"
    );

    await fillIn(".new-value-input.key", "");
    await fillIn(".new-value-input.secret", "thirdValue");
    await click(".add-value-btn");

    assert.ok(
      find(".values .value").length === 2,
      "it doesn't add the value to the list if key is missing"
    );

    await fillIn(".new-value-input.key", "thirdKey");
    await fillIn(".new-value-input.secret", "thirdValue");
    await click(".add-value-btn");

    assert.ok(
      find(".values .value").length === 3,
      "it adds the value to the list of values"
    );

    assert.deepEqual(
      this.get("values"),
      "firstKey|FirstValue\nsecondKey|secondValue\nthirdKey|thirdValue",
      "it adds the value to the list of values"
    );
  }
});

componentTest("removing a value", {
  template: "{{secret-value-list values=values}}",

  async test(assert) {
    this.set("values", "firstKey|FirstValue\nsecondKey|secondValue");

    await click(".values .value[data-index='0'] .remove-value-btn");

    assert.ok(
      find(".values .value").length === 1,
      "it removes the value from the list of values"
    );

    assert.equal(
      this.get("values"),
      "secondKey|secondValue",
      "it removes the expected value"
    );
  }
});
