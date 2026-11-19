import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReactionFeed, {
  MAX_VISIBLE_REACTIONS,
} from "discourse/plugins/live/discourse/lib/live/reaction-feed";

function reaction(roomId, emoji = "clap") {
  return { roomId, userId: 1, username: "sam", emoji };
}

module("Live | Unit | Lib | reaction-feed", function () {
  test("scopes reactions to their room", function (assert) {
    const feed = new ReactionFeed();
    feed.add(reaction(1, "clap"));
    feed.add(reaction("2", "heart"));

    assert.deepEqual(
      feed.forRoom(1).map((entry) => entry.emoji),
      ["clap"]
    );
    assert.deepEqual(
      feed.forRoom(2).map((entry) => entry.emoji),
      ["heart"],
      "room ids are compared numerically"
    );
  });

  test("expires reactions once they've floated by", async function (assert) {
    const feed = new ReactionFeed();
    feed.add(reaction(1));

    await settled();

    assert.deepEqual(feed.forRoom(1), []);
  });

  test("drops the oldest reactions beyond the visible cap", function (assert) {
    const feed = new ReactionFeed();
    const first = feed.add(reaction(1));
    for (let i = 0; i < MAX_VISIBLE_REACTIONS; i++) {
      feed.add(reaction(1));
    }

    assert.strictEqual(feed.forRoom(1).length, MAX_VISIBLE_REACTIONS);
    assert.false(
      feed.forRoom(1).some((entry) => entry.id === first.id),
      "the oldest reaction made room"
    );
  });

  test("clearRoom leaves other rooms untouched", function (assert) {
    const feed = new ReactionFeed();
    feed.add(reaction(1));
    feed.add(reaction(2));

    feed.clearRoom(1);

    assert.strictEqual(feed.forRoom(1).length, 0);
    assert.strictEqual(feed.forRoom(2).length, 1);
  });
});
