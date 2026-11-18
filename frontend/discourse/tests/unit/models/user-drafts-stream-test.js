import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import UserDraftsStream from "discourse/models/user-drafts-stream";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

function draft(i) {
  return {
    draft_key: `new_topic_${i}`,
    sequence: 0,
    draft_username: "eviltrout",
    created_at: "2026-10-24T10:00:00.000Z",
    data: JSON.stringify({ title: `Draft ${i}`, reply: `Reply ${i}` }),
  };
}

module("Unit | Model | user-drafts-stream", function (hooks) {
  setupTest(hooks);

  test("pages through drafts until a short page comes back", async function (assert) {
    const offsets = [];
    pretender.get("/drafts.json", (request) => {
      const offset = parseInt(request.queryParams.offset, 10);
      offsets.push(offset);
      const count = offset === 0 ? 30 : 1;
      return response({
        drafts: Array.from({ length: count }, (_, i) => draft(offset + i)),
      });
    });

    const stream = UserDraftsStream.create({
      user: getOwner(this).lookup("service:current-user"),
    });

    await stream.findItems();
    assert.strictEqual(stream.content.length, 30);
    assert.true(stream.hasMore, "a full page means there may be more");

    await stream.findItems();
    assert.strictEqual(stream.content.length, 31);
    assert.false(stream.hasMore, "a short page ends pagination");

    await stream.findItems();
    assert.deepEqual(offsets, [0, 30], "stops requesting once exhausted");
  });

  test("pages through discarded drafts the same way", async function (assert) {
    pretender.get("/discarded_drafts.json", (request) => {
      const offset = parseInt(request.queryParams.offset, 10);
      const count = offset === 0 ? 30 : 2;
      return response({
        discarded_drafts: Array.from({ length: count }, (_, i) => ({
          ...draft(offset + i),
          id: offset + i + 1,
          deleted_at: "2026-10-24T11:00:00.000Z",
        })),
      });
    });

    const stream = UserDraftsStream.create({
      user: getOwner(this).lookup("service:current-user"),
      discarded: true,
    });

    await stream.findItems();
    assert.true(stream.hasMore);

    await stream.findItems();
    assert.strictEqual(stream.content.length, 32);
    assert.false(stream.hasMore);
  });
});
