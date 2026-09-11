import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { setEnvironment } from "discourse/lib/environment";
import DeprecationCounter from "discourse/tests/helpers/deprecation-counter";

module("Unit | Lib | deprecation-counter", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.sandbox = sinon.createSandbox();
    this.sandbox.stub(window, "Testem").value(undefined);
    this.log = this.sandbox.stub(console, "log");
    this.count = this.sandbox.stub(console, "count");
    setEnvironment("test");
  });

  hooks.afterEach(function () {
    setEnvironment("qunit-testing");
    this.sandbox.restore();
  });

  test("keeps details from separate counters distinct outside a test", function (assert) {
    setEnvironment("qunit-testing");
    const reported = [];
    window.Testem = {
      useCustomAdapter(callback) {
        callback({
          emit(event, tag, { details }) {
            reported.push(...details.map((detail) => ({ ...detail })));
          },
        });
      },
    };
    const counters = [new DeprecationCounter(), new DeprecationCounter()];

    for (const counter of counters) {
      for (let i = 0; i < 3; i++) {
        counter.recordDetail("parallel.deprecation");
      }
    }

    assert.strictEqual(
      reported.length,
      2,
      "each counter reports one new entry"
    );
    assert.strictEqual(
      reported[0].stack,
      reported[1].stack,
      "both counters capture the same stack"
    );
    assert.notStrictEqual(
      reported[0].key,
      reported[1].key,
      "separate counters report distinct keys"
    );
    assert.deepEqual(
      counters.flatMap((counter) =>
        counter.takeUpdatedCounts().map(({ key, count }) => ({ key, count }))
      ),
      reported.map(({ key }) => ({ key, count: 3 })),
      "count updates retain each counter's original key and include repeats"
    );
  });

  test("reports system spec details for every occurrence of the same stack", function (assert) {
    const counter = new DeprecationCounter();

    for (let i = 0; i < 50; i++) {
      counter.incrementCount("repeated.deprecation");
    }

    const details = this.log.args.map(([message]) =>
      JSON.parse(message.slice("deprecation_detail:".length))
    );

    assert.strictEqual(this.count.callCount, 50, "every occurrence is counted");
    assert.strictEqual(
      details.length,
      50,
      "every occurrence has source details"
    );
    assert.true(
      details.every(({ id }) => id === "repeated.deprecation"),
      "details identify the repeated deprecation"
    );
    assert.true(details[0].stack.length > 0, "the source stack is captured");
    assert.strictEqual(
      new Set(details.map(({ stack }) => stack)).size,
      1,
      "all occurrences come from the same stack"
    );
  });
});
