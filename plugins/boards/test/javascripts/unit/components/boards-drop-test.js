import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { shouldRefetchMovedCardPayload } from "discourse/plugins/boards/discourse/components/boards-board-viewer";

module("Boards | Unit | Components | boards drop", function (hooks) {
  setupTest(hooks);

  test("moved topic cards without existing topic data require a board refetch", function (assert) {
    assert.true(
      shouldRefetchMovedCardPayload(null, {
        id: 101,
        column_id: 20,
        topic_id: 9001,
      }),
      "it refetches when a new topic card payload omits the topic"
    );
    assert.false(
      shouldRefetchMovedCardPayload(
        { id: 101, topic_id: 9001, topic: { id: 9001 } },
        { id: 101, column_id: 20, topic_id: 9001 }
      ),
      "it merges stripped payloads for cards already visible to the client"
    );
    assert.false(
      shouldRefetchMovedCardPayload(null, { id: 102, column_id: 20 }),
      "it does not refetch floating cards"
    );
  });
});
