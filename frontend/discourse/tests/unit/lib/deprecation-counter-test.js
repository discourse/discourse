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

  test("preserves call-site attribution in browser and system spec details", function (assert) {
    const reported = [];
    window.Testem = {
      useCustomAdapter(callback) {
        callback({
          emit(event, tag, payload) {
            if (tag === "deprecation-details") {
              reported.push(...payload.details);
            }
          },
        });
      },
    };
    const counter = new DeprecationCounter();

    for (const reportAtCallSite of [true, false]) {
      counter.handleDiscourseDeprecation("Example", {
        id: "example.deprecation",
        reportAtCallSite,
      });
    }

    assert.deepEqual(
      reported.map((detail) => detail.reportAtCallSite),
      [true, false],
      "browser details keep distinct attribution modes for the same stack"
    );
    assert.deepEqual(
      this.log.args.map(
        ([message]) =>
          JSON.parse(message.slice("deprecation_detail:".length))
            .reportAtCallSite
      ),
      [true, false],
      "system spec logs preserve the attribution mode"
    );
  });

  test("keeps counting after exhausting the stack capture budget", function (assert) {
    const counter = new DeprecationCounter();
    const capture = this.sandbox
      .stub(window, "Error")
      .callsFake(() => ({ stack: "repeated stack" }));
    capture.resetHistory();

    try {
      for (let i = 0; i < 10005; i++) {
        counter.incrementCount("repeated.deprecation");
      }
      counter.incrementCount("later.deprecation");
    } finally {
      capture.restore();
    }

    assert.strictEqual(capture.callCount, 10000, "stack captures are bounded");
    assert.strictEqual(
      this.log.callCount,
      10000,
      "details are only emitted within the capture budget"
    );
    assert.strictEqual(
      this.count.callCount,
      10006,
      "every occurrence is still reported to system specs"
    );
    assert.strictEqual(
      counter.counts.get("repeated.deprecation"),
      10005,
      "repeated warnings continue to be counted"
    );
    assert.strictEqual(
      counter.counts.get("later.deprecation"),
      1,
      "new warnings continue to be counted"
    );
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
      counters.flatMap((counter) => counter.takeUpdatedCounts()),
      reported.map(({ key }) => ({ key, count: 3 })),
      "updates contain only each counter's original key and cumulative count"
    );
    assert.deepEqual(
      counters.flatMap((counter) => counter.takeUpdatedCounts()),
      [],
      "unchanged counts are not sent again"
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
