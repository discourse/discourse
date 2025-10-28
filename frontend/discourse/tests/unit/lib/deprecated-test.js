import { deprecate as emberDeprecate } from "@ember/debug";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Sinon from "sinon";
import deprecated, {
  withSilencedDeprecations,
  withSilencedDeprecationsAsync,
} from "discourse/lib/deprecated";
import DeprecationCounter from "discourse/tests/helpers/deprecation-counter";
import {
  disableRaiseOnDeprecation,
  disableRaiseOnDeprecationQUnitResult,
  enableRaiseOnDeprecation,
  enableRaiseOnDeprecationQUnitResult,
} from "discourse/tests/helpers/raise-on-deprecation";

module("Unit | Utility | deprecated", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    disableRaiseOnDeprecation();
    this.warnStub = Sinon.stub(console, "warn");
    this.counterStub = Sinon.stub(
      DeprecationCounter.prototype,
      "incrementCount"
    );
  });

  hooks.afterEach(function () {
    this.warnStub.restore();
    this.counterStub.restore();
    enableRaiseOnDeprecation();
  });

  test("works with just a message", function (assert) {
    deprecated("My message");
    assert.strictEqual(
      this.warnStub.callCount,
      1,
      "console warn was called once"
    );
    assert.deepEqual(
      this.warnStub.args[0],
      ["Deprecation notice: My message"],
      "console.warn is called with the correct arguments"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      1,
      "incrementCount was called once"
    );
    assert.deepEqual(
      this.counterStub.args[0],
      ["discourse.(unknown)"],
      "incrementCount is called with the correct arguments"
    );
  });

  test("works with a message and id", function (assert) {
    deprecated("My message", { id: "discourse.my_deprecation_id" });
    assert.strictEqual(
      this.warnStub.callCount,
      1,
      "console warn was called once"
    );
    assert.deepEqual(
      this.warnStub.args[0],
      [
        "Deprecation notice: My message [deprecation id: discourse.my_deprecation_id]",
      ],
      "console.warn is called with the correct arguments"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      1,
      "incrementCount was called once"
    );
    assert.deepEqual(
      this.counterStub.args[0],
      ["discourse.my_deprecation_id"],
      "incrementCount is called with the correct arguments"
    );
  });

  test("works with all other metadata", async function (assert) {
    deprecated("My message", {
      id: "discourse.my_deprecation_id",
      dropFrom: "v100",
      since: "v1",
      url: "https://example.com",
    });
    assert.strictEqual(
      this.warnStub.callCount,
      1,
      "console warn was called once"
    );
    assert.deepEqual(
      this.warnStub.args[0],
      [
        "Deprecation notice: My message [deprecated since Discourse v1] [removal in Discourse v100] [deprecation id: discourse.my_deprecation_id] [info: https://example.com]",
      ],
      "console.warn is called with the correct arguments"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      1,
      "incrementCount was called once"
    );
    assert.deepEqual(
      this.counterStub.args[0],
      ["discourse.my_deprecation_id"],
      "incrementCount is called with the correct arguments"
    );
  });

  test("works with raiseError", function (assert) {
    assert.throws(
      () =>
        deprecated("My message", {
          id: "discourse.my_deprecation_id",
          raiseError: true,
        }),
      "Deprecation notice: My message [deprecation id: discourse.my_deprecation_id]"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      1,
      "incrementCount was called once"
    );
    assert.deepEqual(
      this.counterStub.args[0],
      ["discourse.my_deprecation_id"],
      "incrementCount is called with the correct arguments"
    );
  });

  test("can silence individual deprecations in tests", function (assert) {
    withSilencedDeprecations("discourse.one", () =>
      deprecated("message", { id: "discourse.one" })
    );
    assert.strictEqual(
      this.warnStub.callCount,
      0,
      "console.warn is not called"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      0,
      "counter is not incremented"
    );

    deprecated("message", { id: "discourse.one" });
    assert.strictEqual(
      this.warnStub.callCount,
      1,
      "console.warn is called outside the silenced function"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      1,
      "counter is incremented outside the silenced function"
    );

    withSilencedDeprecations("discourse.one", () =>
      deprecated("message", { id: "discourse.two" })
    );
    assert.strictEqual(
      this.warnStub.callCount,
      2,
      "console.warn is called for a different deprecation"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      2,
      "counter is incremented for a different deprecation"
    );
  });

  test("can silence multiple deprecations in tests", function (assert) {
    withSilencedDeprecations(["discourse.one", "discourse.two"], () => {
      deprecated("message", { id: "discourse.one" });
      deprecated("message", { id: "discourse.two" });
    });
    assert.strictEqual(
      this.warnStub.callCount,
      0,
      "console.warn is not called"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      0,
      "counter is not incremented"
    );
  });

  test("can use Regex to silence deprecations", function (assert) {
    withSilencedDeprecations(/discourse\..+/, () => {
      deprecated("message", { id: "discourse.one" });
      deprecated("message", { id: "discourse.two" });
    });
    assert.strictEqual(
      this.warnStub.callCount,
      0,
      "console.warn is not called"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      0,
      "counter is not incremented"
    );

    withSilencedDeprecations(
      [/.+method.+/, /.+property/, "discourse.other-deprecation"],
      () => {
        deprecated("message", { id: "discourse.array-method1" });
        deprecated("message", { id: "discourse.array-method2" });
        deprecated("message", { id: "discourse.array-property" });
        deprecated("message", { id: "discourse.other-deprecation" });
      }
    );
    assert.strictEqual(
      this.warnStub.callCount,
      0,
      "console.warn is not called"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      0,
      "counter is not incremented"
    );
  });

  test("can silence deprecations with async callback in tests", async function (assert) {
    await withSilencedDeprecationsAsync("discourse.one", async () => {
      await Promise.resolve();
      deprecated("message", { id: "discourse.one" });
    });
    assert.strictEqual(
      this.warnStub.callCount,
      0,
      "console.warn is not called"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      0,
      "counter is not incremented"
    );

    deprecated("message", { id: "discourse.one" });
    assert.strictEqual(
      this.warnStub.callCount,
      1,
      "console.warn is called outside the silenced function"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      1,
      "counter is incremented outside the silenced function"
    );
  });

  test("can use Regex to silence deprecations with async callbacks", async function (assert) {
    await withSilencedDeprecationsAsync(/discourse\..+/, async () => {
      await Promise.resolve();
      deprecated("message", { id: "discourse.one" });
      deprecated("message", { id: "discourse.two" });
    });
    assert.strictEqual(
      this.warnStub.callCount,
      0,
      "console.warn is not called"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      0,
      "counter is not incremented"
    );

    await withSilencedDeprecationsAsync(
      [/.+method.+/, /.+property/, "discourse.other-deprecation"],
      async () => {
        await Promise.resolve();
        deprecated("message", { id: "discourse.array-method1" });
        deprecated("message", { id: "discourse.array-method2" });
        deprecated("message", { id: "discourse.array-property" });
        deprecated("message", { id: "discourse.other-deprecation" });
      }
    );
    assert.strictEqual(
      this.warnStub.callCount,
      0,
      "console.warn is not called"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      0,
      "counter is not incremented"
    );
  });

  test("can silence Ember deprecations", function (assert) {
    withSilencedDeprecations("fake-ember-deprecation", () => {
      emberDeprecate("fake ember deprecation message", false, {
        id: "fake-ember-deprecation",
        for: "not-ember-source",
        since: "v0",
        until: "v999",
      });
    });
    assert.strictEqual(
      this.warnStub.callCount,
      0,
      "console.warn is not called"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      0,
      "counter is not incremented"
    );
  });

  test("can use Regex to silence Ember deprecations", function (assert) {
    withSilencedDeprecations(
      [/.+-deprecation.+/, "fake-ember-property"],
      () => {
        emberDeprecate("fake ember deprecation message", false, {
          id: "fake-ember-deprecation1",
          for: "not-ember-source",
          since: "v0",
          until: "v999",
        });
        emberDeprecate("fake ember deprecation message", false, {
          id: "fake-ember-deprecation2",
          for: "not-ember-source",
          since: "v0",
          until: "v999",
        });
        emberDeprecate("fake ember deprecation message", false, {
          id: "fake-ember-property",
          for: "not-ember-source",
          since: "v0",
          until: "v999",
        });
      }
    );
    assert.strictEqual(
      this.warnStub.callCount,
      0,
      "console.warn is not called"
    );
    assert.strictEqual(
      this.counterStub.callCount,
      0,
      "counter is not incremented"
    );
  });
});

module("Unit | Utility | deprecated | raise-on-deprecation", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    disableRaiseOnDeprecationQUnitResult();
    this.warnStub = Sinon.stub(console, "warn");
  });

  hooks.afterEach(function () {
    enableRaiseOnDeprecationQUnitResult();
    this.warnStub.restore();
  });

  test("unhandled deprecations raises an error in tests", function (assert) {
    assert.throws(() => {
      deprecated("My message");
    }, "the error was raised");
  });
});
