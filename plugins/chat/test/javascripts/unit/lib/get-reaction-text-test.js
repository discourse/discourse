import { module, test } from "qunit";
import {
  MAX_DISPLAYED_USERNAMES,
  getReactionText,
} from "discourse/plugins/chat/discourse/lib/get-reaction-text";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Unit | get-reaction-text", function () {
  test("no reaction ", function (assert) {
    const reaction = fabricators.reaction({ count: 0, users: [] });
    const currentUser = fabricators.user();

    assert.strictEqual(getReactionText(reaction, currentUser), undefined);
  });

  test("current user reacted - one reaction", function (assert) {
    const currentUser = fabricators.user();
    const reaction = fabricators.reaction({
      count: 1,
      users: [currentUser],
      reacted: true,
    });

    assert.strictEqual(
      getReactionText(reaction, currentUser),
      "You reacted with :heart:"
    );
  });

  test("current user reacted - two reactions", function (assert) {
    const currentUser = fabricators.user();
    const secondUser = fabricators.user({ username: "martin" });
    const reaction = fabricators.reaction({
      count: 2,
      users: [currentUser, secondUser],
      reacted: true,
    });

    assert.strictEqual(
      getReactionText(reaction, currentUser),
      "You and martin reacted with :heart:"
    );
  });

  test("current user reacted - more than display limit reactions", function (assert) {
    const currentUser = fabricators.user();
    const otherUsers = Array.from(Array(MAX_DISPLAYED_USERNAMES + 1)).map(
      (_, i) => fabricators.user({ username: "user" + i })
    );
    const reaction = fabricators.reaction({
      count: [currentUser].concat(otherUsers).length,
      users: [currentUser].concat(otherUsers),
      reacted: true,
    });

    assert.strictEqual(
      getReactionText(reaction, currentUser),
      "You, user0, user1, user2, user3, user4, user5, user6, user7, user8, user9, user10, user11, user12, user13, user14 and 1 other reacted with :heart:"
    );
  });

  test("current user reacted - less or equal than display limit reactions", function (assert) {
    const currentUser = fabricators.user();
    const otherUsers = Array.from(Array(MAX_DISPLAYED_USERNAMES - 2)).map(
      (_, i) => fabricators.user({ username: "user" + i })
    );
    const reaction = fabricators.reaction({
      count: [currentUser].concat(otherUsers).length,
      users: [currentUser].concat(otherUsers),
      reacted: true,
    });

    assert.strictEqual(
      getReactionText(reaction, currentUser),
      "You, user0, user1, user2, user3, user4, user5, user6, user7, user8, user9, user10, user11 and user12 reacted with :heart:"
    );
  });

  test("current user reacted - one reaction", function (assert) {
    const currentUser = fabricators.user();
    const reaction = fabricators.reaction({
      count: 1,
      users: [currentUser],
      reacted: true,
    });

    assert.strictEqual(
      getReactionText(reaction, currentUser),
      "You reacted with :heart:"
    );
  });

  test("current user reacted - two reactions", function (assert) {
    const currentUser = fabricators.user();
    const secondUser = fabricators.user({ username: "martin" });
    const reaction = fabricators.reaction({
      count: 2,
      users: [currentUser, secondUser],
      reacted: true,
    });

    assert.strictEqual(
      getReactionText(reaction, currentUser),
      "You and martin reacted with :heart:"
    );
  });

  test("current user reacted - more than display limit reactions", function (assert) {
    const currentUser = fabricators.user();
    const otherUsers = Array.from(Array(MAX_DISPLAYED_USERNAMES + 1)).map(
      (_, i) => fabricators.user({ username: "user" + i })
    );
    const reaction = fabricators.reaction({
      count: [currentUser].concat(otherUsers).length,
      users: [currentUser].concat(otherUsers),
      reacted: true,
    });

    assert.strictEqual(
      getReactionText(reaction, currentUser),
      "You, user0, user1, user2, user3, user4, user5, user6, user7, user8, user9, user10, user11, user12, user13, user14 and 1 other reacted with :heart:"
    );
  });

  test("current user reacted - less or equal than display limit reactions", function (assert) {
    const currentUser = fabricators.user();
    const otherUsers = Array.from(Array(MAX_DISPLAYED_USERNAMES - 2)).map(
      (_, i) => fabricators.user({ username: "user" + i })
    );
    const reaction = fabricators.reaction({
      count: [currentUser].concat(otherUsers).length,
      users: [currentUser].concat(otherUsers),
      reacted: true,
    });

    assert.strictEqual(
      getReactionText(reaction, currentUser),
      "You, user0, user1, user2, user3, user4, user5, user6, user7, user8, user9, user10, user11 and user12 reacted with :heart:"
    );
  });

  test("current user didn't react - one reaction", function (assert) {
    const user = fabricators.user({ username: "martin" });
    const reaction = fabricators.reaction({
      count: 1,
      users: [user],
    });

    assert.strictEqual(
      getReactionText(reaction, fabricators.user()),
      "martin reacted with :heart:"
    );
  });

  test("current user didn't react - two reactions", function (assert) {
    const firstUser = fabricators.user({ username: "claude" });
    const secondUser = fabricators.user({ username: "martin" });
    const reaction = fabricators.reaction({
      count: 2,
      users: [firstUser, secondUser],
    });

    assert.strictEqual(
      getReactionText(reaction, fabricators.user()),
      "claude and martin reacted with :heart:"
    );
  });

  test("current user didn't react - more than display limit reactions", function (assert) {
    const users = Array.from(Array(MAX_DISPLAYED_USERNAMES + 1)).map((_, i) =>
      fabricators.user({ username: "user" + i })
    );
    const reaction = fabricators.reaction({
      count: users.length,
      users,
    });

    assert.strictEqual(
      getReactionText(reaction, fabricators.user()),
      "user0, user1, user2, user3, user4, user5, user6, user7, user8, user9, user10, user11, user12, user13, user14 and 1 other reacted with :heart:"
    );
  });

  test("current user didn't react - less or equal than display limit reactions", function (assert) {
    const users = Array.from(Array(MAX_DISPLAYED_USERNAMES - 1)).map((_, i) =>
      fabricators.user({ username: "user" + i })
    );
    const reaction = fabricators.reaction({
      count: users.length,
      users,
    });

    assert.strictEqual(
      getReactionText(reaction, fabricators.user()),
      "user0, user1, user2, user3, user4, user5, user6, user7, user8, user9, user10, user11, user12 and user13 reacted with :heart:"
    );
  });
});
