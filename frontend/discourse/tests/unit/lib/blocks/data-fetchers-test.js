import { module, test } from "qunit";
import { fetchTags } from "discourse/lib/blocks/-internals/fetch-tags";
import { fetchUsers } from "discourse/lib/blocks/-internals/fetch-users";

module("Unit | Lib | blocks | fetch-tags", function () {
  test("sorts by popularity (total usage) and slices to count", async function (assert) {
    const store = {
      findAll: async () => [
        { name: "alpha", count: 1 },
        { name: "bravo", count: 9 },
        { name: "charlie", count: 5 },
      ],
    };

    const tags = await fetchTags({ store, count: 2, sort: "popular" });
    assert.deepEqual(
      tags.map((t) => t.name),
      ["bravo", "charlie"],
      "most-used tags first, limited to count"
    );
  });

  test("sorts alphabetically by name", async function (assert) {
    const store = {
      findAll: async () => [
        { name: "charlie", count: 9 },
        { name: "alpha", count: 1 },
        { name: "bravo", count: 5 },
      ],
    };

    const tags = await fetchTags({ store, count: 3, sort: "name" });
    assert.deepEqual(
      tags.map((t) => t.name),
      ["alpha", "bravo", "charlie"]
    );
  });

  test("returns null when there are no tags", async function (assert) {
    const store = { findAll: async () => [] };
    assert.strictEqual(await fetchTags({ store }), null);
  });
});

module("Unit | Lib | blocks | fetch-users", function () {
  test("slices the directory items to count", async function (assert) {
    const store = {
      find: async () => [
        { user: { username: "a" } },
        { user: { username: "b" } },
        { user: { username: "c" } },
      ],
    };

    const users = await fetchUsers({ store, count: 2 });
    assert.strictEqual(users.length, 2, "limited to count");
    assert.strictEqual(users[0].user.username, "a", "preserves order");
  });

  test("passes the period and order through to the store query", async function (assert) {
    let captured;
    const store = {
      find: async (_type, params) => {
        captured = params;
        return [{ user: { username: "a" } }];
      },
    };

    await fetchUsers({ store, period: "monthly", order: "post_count" });
    assert.strictEqual(captured.period, "monthly");
    assert.strictEqual(captured.order, "post_count");
    assert.false(captured.asc, "ranks descending");
  });

  test("returns null when the directory is empty", async function (assert) {
    const store = { find: async () => [] };
    assert.strictEqual(await fetchUsers({ store }), null);
  });
});
