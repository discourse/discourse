import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import CoreFabricators from "discourse/lib/fabricators";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import {
  getReactionText,
  MAX_DISPLAYED_USERNAMES,
} from "discourse/plugins/chat/discourse/lib/get-reaction-text";

module("Discourse Chat | Unit | get-reaction-text", function (hooks) {
  setupTest(hooks);

  test("no reaction", function (assert) {
    const reaction = new ChatFabricators(getOwner(this)).reaction({
      count: 0,
      users: [],
    });
    const currentUser = new CoreFabricators(getOwner(this)).user();

    assert.strictEqual(getReactionText(reaction, currentUser), undefined);
  });

  test("current user reacted - one reaction", function (assert) {
    const currentUser = new CoreFabricators(getOwner(this)).user();
    const reaction = new ChatFabricators(getOwner(this)).reaction({
      count: 1,
      users: [currentUser],
      reacted: true,
    });

    assert.strictEqual(
      getReactionText(reaction, currentUser),
      "<span>You reacted with </span>:heart:"
    );
  });

  test("current user reacted - two reactions", function (assert) {
    const currentUser = new CoreFabricators(getOwner(this)).user();
    const secondUser = new CoreFabricators(getOwner(this)).user({
      username: "martin",
    });
    const reaction = new ChatFabricators(getOwner(this)).reaction({
      count: 2,
      users: [currentUser, secondUser],
      reacted: true,
    });

    assert.strictEqual(
      getReactionText(reaction, currentUser),
      "<span>You and martin reacted with </span>:heart:"
    );
  });

  test("current user reacted - more than display limit reactions", function (assert) {
    const currentUser = new CoreFabricators(getOwner(this)).user();
    const otherUsers = Array.from(Array(MAX_DISPLAYED_USERNAMES + 1)).map(
      (_, i) =>
        new CoreFabricators(getOwner(this)).user({ username: "user" + i })
    );
    const reaction = new ChatFabricators(getOwner(this)).reaction({
      count: [currentUser].concat(otherUsers).length,
      users: [currentUser].concat(otherUsers),
      reacted: true,
    });

    assert.strictEqual(
      getReactionText(reaction, currentUser),
      "<span>You, user0, user1, user2, user3, user4, user5, user6, user7, user8, user9, user10, user11, user12, user13, user14 and 1 other reacted with </span>:heart:"
    );
  });

  test("current user reacted - less or equal than display limit reactions", function (assert) {
    const currentUser = new CoreFabricators(getOwner(this)).user();
    const otherUsers = Array.from(Array(MAX_DISPLAYED_USERNAMES - 2)).map(
      (_, i) =>
        new CoreFabricators(getOwner(this)).user({ username: "user" + i })
    );
    const reaction = new ChatFabricators(getOwner(this)).reaction({
      count: [currentUser].concat(otherUsers).length,
      users: [currentUser].concat(otherUsers),
      reacted: true,
    });

    assert.strictEqual(
      getReactionText(reaction, currentUser),
      "<span>You, user0, user1, user2, user3, user4, user5, user6, user7, user8, user9, user10, user11 and user12 reacted with </span>:heart:"
    );
  });

  test("current user didn't react - one reaction", function (assert) {
    const user = new CoreFabricators(getOwner(this)).user({
      username: "martin",
    });
    const reaction = new ChatFabricators(getOwner(this)).reaction({
      count: 1,
      users: [user],
    });

    assert.strictEqual(
      getReactionText(reaction, new CoreFabricators(getOwner(this)).user()),
      "<span>martin reacted with </span>:heart:"
    );
  });

  test("current user didn't react - two reactions", function (assert) {
    const firstUser = new CoreFabricators(getOwner(this)).user({
      username: "claude",
    });
    const secondUser = new CoreFabricators(getOwner(this)).user({
      username: "martin",
    });
    const reaction = new ChatFabricators(getOwner(this)).reaction({
      count: 2,
      users: [firstUser, secondUser],
    });

    assert.strictEqual(
      getReactionText(reaction, new CoreFabricators(getOwner(this)).user()),
      "<span>claude and martin reacted with </span>:heart:"
    );
  });

  test("current user didn't react - more than display limit reactions", function (assert) {
    const users = Array.from(Array(MAX_DISPLAYED_USERNAMES + 1)).map((_, i) =>
      new CoreFabricators(getOwner(this)).user({ username: "user" + i })
    );
    const reaction = new ChatFabricators(getOwner(this)).reaction({
      count: users.length,
      users,
    });

    assert.strictEqual(
      getReactionText(reaction, new CoreFabricators(getOwner(this)).user()),
      "<span>user0, user1, user2, user3, user4, user5, user6, user7, user8, user9, user10, user11, user12, user13, user14 and 1 other reacted with </span>:heart:"
    );
  });

  test("current user didn't react - less or equal than display limit reactions", function (assert) {
    const users = Array.from(Array(MAX_DISPLAYED_USERNAMES - 1)).map((_, i) =>
      new CoreFabricators(getOwner(this)).user({ username: "user" + i })
    );
    const reaction = new ChatFabricators(getOwner(this)).reaction({
      count: users.length,
      users,
    });

    assert.strictEqual(
      getReactionText(reaction, new CoreFabricators(getOwner(this)).user()),
      "<span>user0, user1, user2, user3, user4, user5, user6, user7, user8, user9, user10, user11, user12 and user13 reacted with </span>:heart:"
    );
  });
});
