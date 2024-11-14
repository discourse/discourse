import { set } from "@ember/object";
import { getOwner } from "@ember/owner";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

acceptance("Discourse Chat | Unit | Service | chat-guardian", function (needs) {
  needs.hooks.beforeEach(function () {
    Object.defineProperty(this, "chatGuardian", {
      get: () => this.container.lookup("service:chat-guardian"),
    });
    Object.defineProperty(this, "siteSettings", {
      get: () => this.container.lookup("service:site-settings"),
    });
    Object.defineProperty(this, "currentUser", {
      get: () => this.container.lookup("service:current-user"),
    });
  });

  needs.user();
  needs.settings();

  test("#canEditChatChannel", async function (assert) {
    set(this.currentUser, "has_chat_enabled", false);
    set(this.currentUser, "admin", false);
    set(this.currentUser, "moderator", false);
    this.siteSettings.chat_enabled = false;
    assert.false(this.chatGuardian.canEditChatChannel());

    set(this.currentUser, "has_chat_enabled", true);
    set(this.currentUser, "admin", true);
    this.siteSettings.chat_enabled = false;
    assert.false(this.chatGuardian.canEditChatChannel());

    set(this.currentUser, "has_chat_enabled", false);
    set(this.currentUser, "admin", false);
    set(this.currentUser, "moderator", false);
    this.siteSettings.chat_enabled = true;
    assert.false(this.chatGuardian.canEditChatChannel());

    set(this.currentUser, "has_chat_enabled", false);
    set(this.currentUser, "admin", true);
    this.siteSettings.chat_enabled = true;
    assert.false(this.chatGuardian.canEditChatChannel());

    set(this.currentUser, "has_chat_enabled", true);
    set(this.currentUser, "admin", false);
    set(this.currentUser, "moderator", false);
    this.siteSettings.chat_enabled = true;
    assert.false(this.chatGuardian.canEditChatChannel());

    set(this.currentUser, "has_chat_enabled", true);
    set(this.currentUser, "admin", true);
    this.siteSettings.chat_enabled = true;
    assert.ok(this.chatGuardian.canEditChatChannel());
  });

  test("#canUseChat", async function (assert) {
    set(this.currentUser, "has_chat_enabled", false);
    this.siteSettings.chat_enabled = true;
    assert.false(this.chatGuardian.canUseChat());

    set(this.currentUser, "has_chat_enabled", true);
    this.siteSettings.chat_enabled = false;
    assert.false(this.chatGuardian.canUseChat());

    set(this.currentUser, "has_chat_enabled", true);
    this.siteSettings.chat_enabled = true;
    assert.ok(this.chatGuardian.canUseChat());
  });

  test("#canArchiveChannel", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).channel();

    set(this.currentUser, "has_chat_enabled", true);
    set(this.currentUser, "admin", true);
    this.siteSettings.chat_enabled = true;
    this.siteSettings.chat_allow_archiving_channels = true;
    assert.ok(this.chatGuardian.canArchiveChannel(channel));

    set(this.currentUser, "admin", false);
    set(this.currentUser, "moderator", false);
    assert.false(this.chatGuardian.canArchiveChannel(channel));
    set(this.currentUser, "admin", true);
    set(this.currentUser, "moderator", true);

    channel.status = "read_only";
    assert.false(this.chatGuardian.canArchiveChannel(channel));
    channel.status = "open";

    channel.status = "archived";
    assert.false(this.chatGuardian.canArchiveChannel(channel));
    channel.status = "open";
  });
});
