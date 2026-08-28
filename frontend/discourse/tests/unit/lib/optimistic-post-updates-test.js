import { module, test } from "qunit";
import {
  consumeOptimisticPostUpdate,
  registerOptimisticPostUpdate,
} from "discourse/lib/optimistic-post-updates";

module("Unit | Lib | optimistic-post-updates", function () {
  test("reconciliation is completed only once by the originating event", async function (assert) {
    const { reconciled } = registerOptimisticPostUpdate("originating-mutation");
    let pageReconciled = false;
    void reconciled.then(() => (pageReconciled = true));

    assert.strictEqual(
      consumeOptimisticPostUpdate(),
      undefined,
      "an event without a token is not optimistic"
    );
    assert.strictEqual(
      consumeOptimisticPostUpdate("another-mutation"),
      undefined,
      "another client's token is not consumed"
    );

    const completeReconciliation = consumeOptimisticPostUpdate(
      "originating-mutation"
    );
    assert.strictEqual(
      typeof completeReconciliation,
      "function",
      "the originating event claims the pending update"
    );
    assert.strictEqual(
      consumeOptimisticPostUpdate("originating-mutation"),
      completeReconciliation,
      "duplicate synchronous listeners share the reconciliation"
    );

    assert.false(
      pageReconciled,
      "claiming the event does not complete page reconciliation"
    );
    completeReconciliation();
    await reconciled;
    assert.true(pageReconciled, "the event completes page reconciliation");
    assert.strictEqual(
      consumeOptimisticPostUpdate("originating-mutation"),
      undefined,
      "the completed token cannot be replayed by a later event"
    );
  });

  test("unregistering completes pending reconciliation", async function (assert) {
    const { reconciled, unregister } =
      registerOptimisticPostUpdate("failed-mutation");

    unregister();
    await reconciled;

    assert.strictEqual(
      consumeOptimisticPostUpdate("failed-mutation"),
      undefined,
      "the mutation is no longer pending"
    );
  });
});
