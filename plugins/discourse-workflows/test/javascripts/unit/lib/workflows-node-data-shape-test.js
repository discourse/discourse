import { module, test } from "qunit";
import {
  continuesOnError,
  withContinueOnError,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/node-data-shape";

module("Unit | lib | discourse-workflows | node-data-shape", function () {
  test("continuesOnError", function (assert) {
    assert.true(continuesOnError({ onError: "continueRegularOutput" }));
    assert.true(continuesOnError({ continueOnFail: true }), "legacy flag");
    assert.false(
      continuesOnError({ onError: "stopWorkflow", continueOnFail: true }),
      "onError wins over the legacy flag"
    );
    assert.false(continuesOnError(undefined));
  });

  test("withContinueOnError", function (assert) {
    assert.deepEqual(
      withContinueOnError({ onError: "continueErrorOutput" }, true),
      {},
      "keeps an unchanged mode"
    );
    assert.deepEqual(withContinueOnError({}, true), {
      onError: "continueRegularOutput",
      continueOnFail: undefined,
    });
    assert.deepEqual(withContinueOnError({ continueOnFail: true }, false), {
      onError: undefined,
      continueOnFail: undefined,
    });
  });
});
