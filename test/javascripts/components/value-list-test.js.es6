import selectKit from "helpers/select-kit-helper";
import componentTest from "helpers/component-test";
moduleForComponent("value-list", { integration: true });

componentTest("adding a value", {
  template: "{{value-list values=values}}",

  skip: true,

  beforeEach() {
    this.set("values", "vinkas\nosama");
  },

  async test(assert) {
    await selectKit().expand();
    await selectKit().fillInFilter("eviltrout");
    await selectKit().keyboard("enter");

    assert.ok(
      find(".values .value").length === 3,
      "it adds the value to the list of values"
    );

    assert.deepEqual(
      this.values,
      "vinkas\nosama\neviltrout",
      "it adds the value to the list of values"
    );
  }
});

componentTest("removing a value", {
  template: "{{value-list values=values}}",

  beforeEach() {
    this.set("values", "vinkas\nosama");
  },

  async test(assert) {
    await click(".values .value[data-index='0'] .remove-value-btn");

    assert.ok(
      find(".values .value").length === 1,
      "it removes the value from the list of values"
    );

    assert.equal(this.values, "osama", "it removes the expected value");
  }
});

componentTest("selecting a value", {
  template: "{{value-list values=values choices=choices}}",

  beforeEach() {
    this.setProperties({
      values: "vinkas\nosama",
      choices: ["maja", "michael"]
    });
  },

  async test(assert) {
    await selectKit().expand();
    await selectKit().selectRowByValue("maja");

    assert.ok(
      find(".values .value").length === 3,
      "it adds the value to the list of values"
    );

    assert.deepEqual(
      this.values,
      "vinkas\nosama\nmaja",
      "it adds the value to the list of values"
    );
  }
});

componentTest("array support", {
  template: "{{value-list values=values inputType='array'}}",

  beforeEach() {
    this.set("values", ["vinkas", "osama"]);
  },

  async test(assert) {
    this.set("values", ["vinkas", "osama"]);

    await selectKit().expand();
    await selectKit().fillInFilter("eviltrout");
    await selectKit().keyboard("enter");

    assert.ok(
      find(".values .value").length === 3,
      "it adds the value to the list of values"
    );

    assert.deepEqual(
      this.values,
      ["vinkas", "osama", "eviltrout"],
      "it adds the value to the list of values"
    );
  }
});

componentTest("delimiter support", {
  template: "{{value-list values=values inputDelimiter='|'}}",

  beforeEach() {
    this.set("values", "vinkas|osama");
  },

  skip: true,

  async test(assert) {
    await selectKit().expand();
    await selectKit().fillInFilter("eviltrout");
    await selectKit().keyboard("enter");

    assert.ok(
      find(".values .value").length === 3,
      "it adds the value to the list of values"
    );

    assert.deepEqual(
      this.values,
      "vinkas|osama|eviltrout",
      "it adds the value to the list of values"
    );
  }
});
