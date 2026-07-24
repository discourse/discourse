import { module, test } from "qunit";
import {
  inputForRun,
  latestRunWithOutput,
  outputForRun,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/run-data";

module("Unit | lib | discourse-workflows | run-data", function () {
  test("latestRunWithOutput includes filtered and skipped runs", function (assert) {
    const filteredRun = {
      status: "filtered",
      outputs: [
        { index: 0, items: [] },
        { index: 1, items: [{ json: { branched: true } }] },
      ],
    };
    const runData = {
      If: [{ status: "success", outputs: [] }, filteredRun],
      Skipped: [{ status: "skipped", outputs: [{ index: 0, items: [] }] }],
      Failed: [{ status: "error", outputs: [] }],
    };

    assert.strictEqual(latestRunWithOutput(runData, "If"), filteredRun);
    assert.strictEqual(
      latestRunWithOutput(runData, "Skipped"),
      runData.Skipped[0]
    );
    assert.strictEqual(latestRunWithOutput(runData, "Failed"), null);
  });

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
