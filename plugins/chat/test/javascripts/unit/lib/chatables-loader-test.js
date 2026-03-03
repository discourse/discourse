import { module, test } from "qunit";
import { sortChatables } from "discourse/plugins/chat/discourse/components/chat/message-creator/lib/chatables-loader";
import {
  MATCH_QUALITY_EXACT,
  MATCH_QUALITY_PARTIAL,
  MATCH_QUALITY_PREFIX,
} from "discourse/plugins/chat/discourse/lib/chat-constants";
import ChatChatable from "discourse/plugins/chat/discourse/models/chat-chatable";

module("Discourse Chat | Unit | lib | chatables-loader", function () {
  function createUserChatable(
    username,
    { has_chat_enabled = true, match_quality = MATCH_QUALITY_PARTIAL } = {}
  ) {
    return ChatChatable.create({
      type: "user",
      identifier: `u-${username}`,
      model: { id: Math.random(), username, has_chat_enabled },
      match_quality,
    });
  }

  function createGroupChatable(
    name,
    { can_chat = true, match_quality = MATCH_QUALITY_PARTIAL } = {}
  ) {
    return ChatChatable.create({
      type: "group",
      identifier: `g-${name}`,
      model: { id: Math.random(), name, can_chat },
      match_quality,
    });
  }

  function createDMChannelChatable(
    title,
    { match_quality = MATCH_QUALITY_PARTIAL } = {}
  ) {
    return ChatChatable.create({
      type: "channel",
      identifier: `c-${title}`,
      model: {
        id: Math.random(),
        title,
        slug: title.toLowerCase(),
        chatable_type: "DirectMessage",
      },
      match_quality,
    });
  }

  function createCategoryChannelChatable(
    title,
    { match_quality = MATCH_QUALITY_PARTIAL } = {}
  ) {
    return ChatChatable.create({
      type: "channel",
      identifier: `c-${title}`,
      model: {
        id: Math.random(),
        title,
        slug: title.toLowerCase(),
        chatable_type: "Category",
      },
      match_quality,
    });
  }

  test("users come before DM channels", function (assert) {
    const chatables = [
      createDMChannelChatable("david-chat", {
        match_quality: MATCH_QUALITY_EXACT,
      }),
      createUserChatable("david", { match_quality: MATCH_QUALITY_EXACT }),
    ];

    const sorted = sortChatables(chatables);
    assert.strictEqual(sorted[0].type, "user");
    assert.strictEqual(sorted[1].type, "channel");
  });

  test("DM channels come before category channels", function (assert) {
    const chatables = [
      createCategoryChannelChatable("dev", {
        match_quality: MATCH_QUALITY_EXACT,
      }),
      createDMChannelChatable("dev-chat", {
        match_quality: MATCH_QUALITY_EXACT,
      }),
    ];

    const sorted = sortChatables(chatables);
    assert.strictEqual(sorted[0].model.chatableType, "DirectMessage");
    assert.strictEqual(sorted[1].model.chatableType, "Category");
  });

  test("category channels come before groups", function (assert) {
    const chatables = [
      createGroupChatable("developers", { match_quality: MATCH_QUALITY_EXACT }),
      createCategoryChannelChatable("dev", {
        match_quality: MATCH_QUALITY_EXACT,
      }),
    ];

    const sorted = sortChatables(chatables);
    assert.strictEqual(sorted[0].type, "channel");
    assert.strictEqual(sorted[1].type, "group");
  });

  test("exact matches come before prefix matches within same type", function (assert) {
    const chatables = [
      createUserChatable("developer", { match_quality: MATCH_QUALITY_PREFIX }),
      createUserChatable("dev", { match_quality: MATCH_QUALITY_EXACT }),
      createUserChatable("devops", { match_quality: MATCH_QUALITY_PREFIX }),
    ];

    const sorted = sortChatables(chatables);
    assert.strictEqual(sorted[0].model.username, "dev");
  });

  test("enabled users come before disabled users with same match quality", function (assert) {
    const chatables = [
      createUserChatable("developer", {
        has_chat_enabled: false,
        match_quality: MATCH_QUALITY_EXACT,
      }),
      createUserChatable("devops", {
        has_chat_enabled: true,
        match_quality: MATCH_QUALITY_EXACT,
      }),
    ];

    const sorted = sortChatables(chatables);
    assert.strictEqual(sorted[0].model.username, "devops");
    assert.strictEqual(sorted[1].model.username, "developer");
  });

  test("chattable groups come before non-chattable groups with same match quality", function (assert) {
    const chatables = [
      createGroupChatable("large-group", {
        can_chat: false,
        match_quality: MATCH_QUALITY_EXACT,
      }),
      createGroupChatable("small-group", {
        can_chat: true,
        match_quality: MATCH_QUALITY_EXACT,
      }),
    ];

    const sorted = sortChatables(chatables);
    assert.strictEqual(sorted[0].model.name, "small-group");
    assert.strictEqual(sorted[1].model.name, "large-group");
  });

  test("prefix matches come before partial matches", function (assert) {
    const chatables = [
      createUserChatable("mydev", { match_quality: MATCH_QUALITY_PARTIAL }),
      createUserChatable("developer", { match_quality: MATCH_QUALITY_PREFIX }),
    ];

    const sorted = sortChatables(chatables);
    assert.strictEqual(sorted[0].model.username, "developer");
    assert.strictEqual(sorted[1].model.username, "mydev");
  });

  test("full prioritization order: match_quality > type > enabled", function (assert) {
    const chatables = [
      createGroupChatable("developers", {
        match_quality: MATCH_QUALITY_PREFIX,
      }),
      createUserChatable("dev", {
        has_chat_enabled: true,
        match_quality: MATCH_QUALITY_EXACT,
      }),
      createUserChatable("dev-disabled", {
        has_chat_enabled: false,
        match_quality: MATCH_QUALITY_EXACT,
      }),
      createUserChatable("devhelper", {
        has_chat_enabled: true,
        match_quality: MATCH_QUALITY_PREFIX,
      }),
      createDMChannelChatable("dev-chat", {
        match_quality: MATCH_QUALITY_EXACT,
      }),
      createCategoryChannelChatable("dev-category", {
        match_quality: MATCH_QUALITY_EXACT,
      }),
    ];

    const sorted = sortChatables(chatables);

    assert.strictEqual(
      sorted[0].model.username,
      "dev",
      "exact match enabled user first"
    );
    assert.strictEqual(
      sorted[1].model.username,
      "dev-disabled",
      "exact match disabled user second"
    );
    assert.strictEqual(
      sorted[2].model.chatableType,
      "DirectMessage",
      "exact match DM channel third"
    );
    assert.strictEqual(
      sorted[3].model.chatableType,
      "Category",
      "exact match category channel fourth"
    );
    assert.strictEqual(
      sorted[4].model.username,
      "devhelper",
      "prefix match user fifth"
    );
    assert.strictEqual(sorted[5].type, "group", "prefix match group last");
  });

  test("exact match group comes before prefix match user", function (assert) {
    const chatables = [
      createUserChatable("devs", {
        has_chat_enabled: true,
        match_quality: MATCH_QUALITY_PREFIX,
      }),
      createGroupChatable("dev", {
        can_chat: true,
        match_quality: MATCH_QUALITY_EXACT,
      }),
    ];

    const sorted = sortChatables(chatables);
    assert.strictEqual(sorted[0].type, "group");
    assert.strictEqual(sorted[1].type, "user");
  });

  test("match quality determines order within same type", function (assert) {
    const chatables = [
      createDMChannelChatable("davidb-chat", {
        match_quality: MATCH_QUALITY_PREFIX,
      }),
      createDMChannelChatable("david-chat", {
        match_quality: MATCH_QUALITY_EXACT,
      }),
      createDMChannelChatable("cvx-david", {
        match_quality: MATCH_QUALITY_EXACT,
      }),
    ];

    const sorted = sortChatables(chatables);
    assert.strictEqual(sorted[0].matchQuality, MATCH_QUALITY_EXACT);
    assert.strictEqual(sorted[1].matchQuality, MATCH_QUALITY_EXACT);
    assert.strictEqual(sorted[2].matchQuality, MATCH_QUALITY_PREFIX);
    assert.strictEqual(sorted[2].model.title, "davidb-chat");
  });
});
