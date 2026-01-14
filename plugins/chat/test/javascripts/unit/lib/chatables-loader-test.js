import { module, test } from "qunit";
import { sortChatables } from "discourse/plugins/chat/discourse/components/chat/message-creator/lib/chatables-loader";
import ChatChatable from "discourse/plugins/chat/discourse/models/chat-chatable";

module("Discourse Chat | Unit | lib | chatables-loader", function () {
  function createUserChatable(username, has_chat_enabled = true) {
    return ChatChatable.create({
      type: "user",
      identifier: `u-${username}`,
      model: { id: Math.random(), username, has_chat_enabled },
    });
  }

  function createGroupChatable(name, can_chat = true) {
    return ChatChatable.create({
      type: "group",
      identifier: `g-${name}`,
      model: { id: Math.random(), name, can_chat },
    });
  }

  function createChannelChatable(title, slug = null) {
    return ChatChatable.create({
      type: "channel",
      identifier: `c-${title}`,
      model: { id: Math.random(), title, slug: slug || title.toLowerCase() },
    });
  }

  test("exact matches come first", function (assert) {
    const chatables = [
      createUserChatable("developer"),
      createUserChatable("dev"),
      createUserChatable("devops"),
    ];

    const sorted = sortChatables(chatables, "dev");
    assert.strictEqual(sorted[0].model.username, "dev");
  });

  test("channels come before users with same match quality", function (assert) {
    const chatables = [
      createUserChatable("dev"),
      createChannelChatable("Dev", "dev"),
    ];

    const sorted = sortChatables(chatables, "dev");
    assert.strictEqual(sorted[0].type, "channel");
    assert.strictEqual(sorted[1].type, "user");
  });

  test("enabled users come before disabled users", function (assert) {
    const chatables = [
      createUserChatable("developer", false),
      createUserChatable("devops", true),
    ];

    const sorted = sortChatables(chatables, "dev");
    assert.strictEqual(sorted[0].model.username, "devops");
    assert.strictEqual(sorted[1].model.username, "developer");
  });

  test("starts-with matches come before contains matches", function (assert) {
    const chatables = [
      createUserChatable("mydev"),
      createUserChatable("developer"),
    ];

    const sorted = sortChatables(chatables, "dev");
    assert.strictEqual(sorted[0].model.username, "developer");
    assert.strictEqual(sorted[1].model.username, "mydev");
  });

  test("full prioritization order", function (assert) {
    const chatables = [
      createUserChatable("developer", false),
      createUserChatable("devhelper", true),
      createChannelChatable("Dev Talk", "dev-talk"),
      createUserChatable("dev", true),
      createChannelChatable("Dev", "dev"),
      createGroupChatable("developers", true),
      createUserChatable("superdev", false),
    ];

    const sorted = sortChatables(chatables, "dev");

    const firstChannelName = sorted[0].model.slug ?? sorted[0].model.title;
    assert.strictEqual(firstChannelName, "dev", "exact match channel first");
    assert.strictEqual(
      sorted[1].model.username,
      "dev",
      "exact match enabled user second"
    );
    assert.strictEqual(sorted[2].type, "channel", "starts-with channel third");
    assert.strictEqual(
      sorted[3].model.username,
      "devhelper",
      "starts-with enabled user"
    );
    assert.strictEqual(
      sorted[4].model.name,
      "developers",
      "starts-with enabled group"
    );
    assert.strictEqual(
      sorted[5].model.username,
      "developer",
      "starts-with disabled user"
    );
    assert.strictEqual(
      sorted[6].model.username,
      "superdev",
      "contains disabled user last"
    );
  });

  test("case insensitive matching", function (assert) {
    const chatables = [
      createUserChatable("DEV"),
      createUserChatable("Dev"),
      createUserChatable("dev"),
    ];

    const sorted = sortChatables(chatables, "DEV");

    assert.strictEqual(sorted.length, 3);
    sorted.forEach((chatable) => {
      assert.strictEqual(
        chatable.model.username.toLowerCase(),
        "dev",
        `${chatable.model.username} should match`
      );
    });
  });

  test("disabled groups come after enabled users", function (assert) {
    const chatables = [
      createGroupChatable("devs", false),
      createUserChatable("devs", true),
    ];

    const sorted = sortChatables(chatables, "devs");
    assert.strictEqual(sorted[0].type, "user");
    assert.strictEqual(sorted[1].type, "group");
  });
});
