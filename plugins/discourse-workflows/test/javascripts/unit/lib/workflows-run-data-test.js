import { module, test } from "qunit";
import {
  inputForRun,
  outputForRun,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/run-data";

module("Unit | lib | discourse-workflows | run-data", function () {
  test("outputForRun keeps output indexes positional", function (assert) {
    const run = {
      outputs: [{ index: 0, items: [{ json: { primary: true } }] }],
    };

    assert.strictEqual(outputForRun(run, 1), null);
  });

  test("inputForRun keeps input indexes positional", function (assert) {
    const run = {
      inputs: [
        {
          index: 1,
          items: [{ json: { topic: { id: 1 } } }],
        },
      ],
    };

    assert.strictEqual(
      inputForRun(run, 0),
      null,
      "does not fall back to a differently indexed input"
    );
  });
});
