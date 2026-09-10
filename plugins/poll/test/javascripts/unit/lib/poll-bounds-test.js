import { module, test } from "qunit";
import pollBounds from "discourse/plugins/poll/lib/poll-bounds";

module("Unit | Lib | poll-bounds", function () {
  test("reads what the markup carries, and fills in what it does not", function (assert) {
    const cases = [
      [{}, 2, { min: 1, max: 2 }],
      [{ min: "1", max: "2" }, 3, { min: 1, max: 2 }],
      [{ min: "0" }, 2, { min: 0, max: 2 }],
      [{ min: "-1" }, 2, { min: 1, max: 2 }],
      [{ min: "abc", max: "abc" }, 2, { min: 1, max: 2 }],
      [{ max: "9" }, 2, { min: 1, max: 2 }],
      [{ max: "0" }, 2, { min: 1, max: 0 }],
      [{ min: "2", max: "2" }, 5, { min: 2, max: 2 }],
      [{ min: "1", max: "2" }, 0, { min: 1, max: 0 }],
    ];

    for (const [poll, optionCount, expected] of cases) {
      assert.deepEqual(
        pollBounds(poll, optionCount),
        expected,
        `${JSON.stringify(poll)} over ${optionCount} options`
      );
    }
  });
});
