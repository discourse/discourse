import { module, test } from "qunit";
import sinon from "sinon";
import {
  consumeOptimisticPostUpdate,
  registerOptimisticPostUpdate,
} from "discourse/lib/optimistic-post-updates";

module("Unit | Lib | optimistic-post-updates", function () {
  test("only the originating event consumes an update", function (assert) {
    registerOptimisticPostUpdate("originating-mutation");

    assert.false(
      consumeOptimisticPostUpdate(),
      "an event without a token is not optimistic"
    );
    assert.false(
      consumeOptimisticPostUpdate("another-mutation"),
      "another client's token is not consumed"
    );
    assert.true(
      consumeOptimisticPostUpdate("originating-mutation"),
      "the originating event consumes the pending update"
    );
    assert.false(
      consumeOptimisticPostUpdate("originating-mutation"),
      "the token cannot be replayed"
    );
  });

  test("unregisters a pending update", function (assert) {
    const { unregister } = registerOptimisticPostUpdate("failed-mutation");

    unregister();

    assert.false(
      consumeOptimisticPostUpdate("failed-mutation"),
      "the mutation is no longer pending"
    );
  });

  test("starts expiration after the mutation request finishes", function (assert) {
    const clock = sinon.useFakeTimers();
    registerOptimisticPostUpdate("in-flight");

    clock.tick(30_000);
    assert.true(
      consumeOptimisticPostUpdate("in-flight"),
      "an in-flight mutation retains its token"
    );

    registerOptimisticPostUpdate("lost-event").startExpiration();
    clock.tick(30_000);
    assert.false(
      consumeOptimisticPostUpdate("lost-event"),
      "a lost event does not retain a completed mutation's token"
    );
    clock.restore();
  });
});
